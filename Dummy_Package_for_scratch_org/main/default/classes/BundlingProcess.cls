public with sharing class BundlingProcess {
    private static final Map<String, String> OPERATIONS_BY_ATTACHMENT = new Map<String, String>{
        'Metadata' => 'Commit Files',
        'Full Profiles & Permission Sets' => 'Full Profiles & Permission Sets',
        'Destructive Changes' => 'Destructive Changes'
    };
    private static final Map<String, String> ATTACHMENTS_BY_OPERATIONS = new Map<String, String>{
        'Commit Files' => 'MetaData',
        'Full Profiles & Permission Sets' => 'MetaData',
        'Destructive Changes' => 'Git Deletion'
    };

    private Map<Id, User_Story__c> childrenStoriesById = new Map<Id, User_Story__c>();
    private Set<Id> environments = new Set<Id>();
    private Set<Id> projects = new Set<Id>();
    private Set<Id> releases = new Set<Id>();
    private List<AggregateResult> pipelines;
    private User_Story__c parentStory;
    private Id pipeline;
    private Id bundle;

    // CONSTRUCTOR

    public BundlingProcess(Id bundleId, User_Story__c userStory) {
        for (User_Story__c story : new UserStoriesSelector().byBundlePackageVersions(new Set<Id>{ bundleId })) {
            childrenStoriesById.put(story.Id, story);
            environments.add(story.Environment__c);
            projects.add(story.Project__c);
            releases.add(story.Release__c);
        }

        environments.add(userStory.Environment__c);
        pipelines = queryPipeline(userStory.Project__c, projects, releases);
        pipeline = (Id) pipelines[0].get(Settings.ns + 'Deployment_Flow__c');
        parentStory = userStory;
        bundle = bundleId;
    }

    // PUBLIC

    public BundlingResult execute() {
        environmentConsistency();
        pipelineConsistency();
        insertParentStory();
        updateBundle();
        updateChildStories();
        cloneDeploymentTasks();
        return commitMetadata();
    }

    // PRIVATE

    private void insertParentStory() {
        parentStory.Is_Bundle__c = true;
        parentStory.RecordTypeId = Schema.SObjectType.User_Story__c.getRecordTypeInfosByDeveloperName().get('Utility').getRecordTypeId();
        parentStory = (User_Story__c) Utilities.Secure_DML(parentStory, Utilities.DML_Action.INS, Schema.SObjectType.User_Story__c);
    }

    private List<AggregateResult> queryPipeline(Id project, Set<Id> projects, Set<Id> releases) {
        Set<Id> allIds = (Set<Id>) Utilities.getFieldValues(new ReleasesSelector().byIds(releases), Release__c.Project__c, Set<Id>.class, false);
        allIds.addAll(projects);
        allIds.add(project);

        return [SELECT Deployment_Flow__c FROM Project__c WHERE Id = :allIds WITH SECURITY_ENFORCED GROUP BY Deployment_Flow__c];
    }

    private void updateBundle() {
        Artifact_Version__c bundle = new Artifact_Version__c(Id = bundle);
        bundle.User_Story__c = parentStory.Id;
        bundle.Status__c = 'Locked';

        Utilities.Secure_DML(bundle, Utilities.DML_Action.UPD, Schema.SObjectType.Artifact_Version__c);
    }

    private void updateChildStories() {
        for (User_Story__c story : childrenStoriesById.values()) {
            story.Stop_Indexing_Metadata__c = true;
            story.Exclude_From_CBM__c = true;
        }

        Utilities.Secure_DML(childrenStoriesById.values(), Utilities.DML_Action.UPD, Schema.SObjectType.User_Story__c);
    }

    private void cloneDeploymentTasks() {
        Set<Id> tasks = new Map<Id, Deployment_Task__c>(new DeploymentTasksSelector().byStories(childrenStoriesById.keyset())).keySet();
        if (!tasks.isEmpty()) {
            String serialized = SObjectDataLoader.serialize(
                tasks,
                new SObjectDataLoader.SerializeConfig().followChild(Attachment.ParentId).omit(Deployment_Task__c.User_Story__c)
            );
            SObjectDataLoader.deserialize(serialized, new SetParentStoryCallback(parentStory));
        }
    }

    private BundlingResult commitMetadata() {
        List<Id> commitIds = new List<Id>();
        List<Git_Org_Commit__c> commits = new List<Git_Org_Commit__c>();
        Map<String, Attachment> attachmentByMessage = new Map<String, Attachment>();
        String snapshotId = queryGitSnapshot(parentStory.Org_Credential__c, pipeline);
        parentStory = new UserStoriesSelector().byIds(new Set<Id>{ parentStory.Id }).get(0);

        for (Attachment attachment : new AttachmentsSelector().byParentIdAndName(new Set<Id>{ bundle }, OPERATIONS_BY_ATTACHMENT.keySet())) {
            String key = parentStory.Name + ': ' + parentStory.User_Story_Title__c + ' Bundle ' + attachment.Name;
            commits.add(createCommit(key, parentStory.Org_Credential__c, snapshotId, OPERATIONS_BY_ATTACHMENT.get(attachment.Name)));
            attachmentByMessage.put(key, attachment.clone());
        }
        Utilities.Secure_DML(commits, Utilities.DML_Action.INS, schema.SObjectType.Git_Org_Commit__c);

        for (Git_Org_Commit__c cmm : commits) {
            commitIds.add(cmm.Id);
            String key = cmm.Commit_Message__c;
            attachmentByMessage.get(key).ParentId = cmm.Id;
            attachmentByMessage.get(key).Name = ATTACHMENTS_BY_OPERATIONS.get(cmm.Git_Operation__c);
        }
        Utilities.Secure_DML(attachmentByMessage.values(), Utilities.DML_Action.INS, schema.SObjectType.Attachment);

        BundlingResult result = new BundlingResult();
        result.storyId = parentStory.Id;
        result.commitIds = commitIds;
        result.snapshotId = snapshotId;
        return result;
    }

    private Id queryGitSnapshot(String orgId, Id pipelineId) {
        Deployment_Flow__c pipeline = new PipelineSelector().byId(new Set<Id>{ pipelineId })[0];
        return new GitSnapshotSelector().byCredentialRepoSnapshotOnly(orgId, pipeline.Git_Repository__c)[0].Id;
    }

    private void environmentConsistency() {
        if (!(environments.size() == 1)) {
            new ApplicationException('Environments in the selection does not match').throwAuraHandled();
        }
    }

    private void pipelineConsistency() {
        if (!(pipelines.size() == 1)) {
            new ApplicationException('Pipelines in the selection does not match').throwAuraHandled();
        }
    }

    private Git_Org_Commit__c createCommit(String commitMessage, String orgId, String snapshotId, String operationName) {
        return new Git_Org_Commit__c(
            Commit_Message__c = commitMessage,
            Org__c = orgId,
            Git_Backup__c = snapshotId,
            Status__c = 'Pending',
            Git_Operation__c = operationName
        );
    }

    private class SetParentStoryCallback implements SObjectDataLoader.IDeserializeCallback {
        private Id scenarioId;

        public SetParentStoryCallback(SObject clone) {
            scenarioId = clone.Id;
        }

        public void unresolvedReferences(SObjectType type, List<SObjectDataLoader.UnresolvedReferences> unresolved) {
            if (type == Deployment_Task__c.SObjectType) {
                for (SObjectDataLoader.UnresolvedReferences refs : unresolved) {
                    if (refs.References.contains(Deployment_Task__c.User_Story__c)) {
                        refs.Record.put(Deployment_Task__c.User_Story__c, scenarioId);
                    }
                }
            }
        }
    }

    //INNER

    public class BundlingResult {
        @AuraEnabled
        public Id storyId;

        @AuraEnabled
        public List<Id> commitIds;

        @AuraEnabled
        public Id snapshotId;
    }
}