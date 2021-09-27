@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class CommitAction implements JobExecutionCallback {
    @InvocableMethod(label='Commit changes' description='Commit your changes' category='Copado Multi-Cloud')
    global static List<Response> commitChanges(List<Request> requests) {
        if (requests.size() > 1) {
            throw new ApplicationException(Label.OnlyOneRequestAvailable);
        }

        // TODO: Query for job execution with parent US and status in progress. If exists, do not continue and throw exception

        // No need of bulkification right now, so keep it simple
        Request request = requests[0];

        if (request.changes.isEmpty()) {
            throw new ApplicationException(Label.ThereShouldBeAtLeastOneChangeToCommit);
        }

        User_Story__c userStory = new UserStoriesSelector().byIdsForMulticloud(new Set<Id>{ request.userStoryId })[0];

        // So far, this checks were taking place on page load
        validateCommitRequirements(userStory);

        if (request.recreateFeatureBranch) {
            deletePreviousUserStoryMetadata(userStory);
        }

        saveChangesAsUserStoryMetadata(request, userStory);

        CreateExecutionRequestData data = new CreateExecutionRequestData(userStory, request).createCommitRecords();

        List<Response> result = new List<Response>();
        if (request.executeCommit) {
            result.add(new Response(executeCommitJobTemplate(request, data, userStory)));
        }
        return result;
    }

    // Job Callback, called only after the job finishes
    global void execute(JobExecution__c job, String status) {
        // TODO: result handling

        job = [SELECT DataJson__c FROM JobExecution__c WHERE Id = :job.Id];
        CreateExecutionRequestData data = (CreateExecutionRequestData) JSON.deserialize(job.DataJson__c, CreateExecutionRequestData.class);

        User_Story__c userStory = new UserStoriesSelector(false, false).byId(new Set<Id>{ data.userStoryId })[0];
        userStory.Latest_Commit_Date__c = System.now();

        // Note: False positive, checked permissions before in this method
        update userStory;

        // TODO: maybe delete file used by job execution? not for now, but likely later
    }

    // PRIVATE

    private static void validateCommitRequirements(User_Story__c userStory) {
        List<String> commitUnavailabilityReasons = getCommitUnavailabilityReasons(userStory);

        if (!commitUnavailabilityReasons.isEmpty()) {
            throw new ApplicationException(
                String.format(Label.CanNotPerformThisAction, new List<Object>{ String.join(commitUnavailabilityReasons, ', ') })
            );
        }
    }

    private static List<String> getCommitUnavailabilityReasons(User_Story__c userStory) {
        List<String> result = new List<String>();

        result.addAll(hasRequiredLicenses());
        result.addAll(hasSobjectPermissions());
        result.addAll(userStoryIsValid(userStory));
        result.addAll(pipelineIsValid(userStory));

        return result;
    }

    private static List<String> hasRequiredLicenses() {
        List<String> result = new List<String>();

        if (LicenseHelper.isLicensesExceeded()) {
            result.add(Label.LICENSES_EXCEEDED);
        }

        if (!LicenseHelper.actionIsLicenseEnabled('commitFiles')) {
            result.add(Label.CCM_License_Restriction);
        }

        if (!FeatureHelper.isChangeChangeManagementEnabled()) {
            result.add(Label.FEATURE_NOT_SUPPORTED);
        }

        return result;
    }

    private static List<String> hasSobjectPermissions() {
        List<String> result = new List<String>();

        if (!Schema.SObjectType.User_Story__c.isUpdateable()) {
            result.add(Label.Insufficient_Access_Rights + ' ' + Label.Related_Object + ' ' + Schema.SObjectType.User_Story__c.Label);
        }

        if (!Schema.SObjectType.Deployment_Flow__c.isAccessible()) {
            result.add(Label.MISSING_PERMISSIONS_CBM_FLOW);
        }

        if (
            !Schema.SObjectType.User_Story_Metadata__c.isCreateable() ||
            !Schema.SObjectType.User_Story_Metadata__c.isUpdateable() ||
            !Schema.SObjectType.User_Story_Metadata__c.isDeletable()
        ) {
            result.add(Label.Insufficient_Access_Rights + ' ' + Label.Related_Object + ' ' + Schema.SObjectType.User_Story_Metadata__c.Label);
        }

        if (!Schema.SObjectType.Git_Commit__c.isCreateable()) {
            result.add(Label.Insufficient_Access_Rights + ' ' + Label.Related_Object + ' ' + Schema.SObjectType.Git_Commit__c.Label);
        }

        if (!Schema.SObjectType.Git_Org_Commit__c.isCreateable()) {
            result.add(Label.Insufficient_Access_Rights + ' ' + Label.Related_Object + ' ' + Schema.SObjectType.Git_Org_Commit__c.Label);
        }

        if (!Schema.SObjectType.User_Story_Commit__c.isCreateable()) {
            result.add(Label.Insufficient_Access_Rights + ' ' + Label.Related_Object + ' ' + Schema.SObjectType.User_Story_Commit__c.Label);
        }

        return result;
    }

    private static List<String> userStoryIsValid(User_Story__c userStory) {
        List<String> result = new List<String>();

        if (String.isBlank(userStory.Project__c)) {
            result.add(Label.UserStoryWithoutProject);
        }

        if (String.isBlank(userStory.Environment__c)) {
            result.add(Label.USER_STORY_COMMIT_NO_ENVIRONMENT);
        }

        if (userStory.Org_Credential__r.Validated_Date__c == null) {
            result.add(Label.Org_Is_Not_Valid);
        }

        result.addAll(hasEditAccesOnCredential(userStory));

        return result;
    }

    private static List<String> hasEditAccesOnCredential(User_Story__c userStory) {
        List<String> result = new List<String>();

        List<UserRecordAccess> credentialAccess = [
            SELECT RecordId, HasEditAccess
            FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId() AND RecordId = :userStory.Org_Credential__c
        ];

        if (!credentialAccess.isEmpty() && !credentialAccess[0].HasEditAccess) {
            result.add(Label.Read_Write_Access_Missing);
        }

        return result;
    }

    private static List<String> pipelineIsValid(User_Story__c userStory) {
        List<String> result = new List<String>();
        GlobalUtilities.deploymentFlowDetails flowDetails = GlobalUtilities.getUserStoryDeploymentFlowDetails(userStory.Id, '');

        if (flowDetails.flow == null || !flowDetails.flow.Active__c) {
            result.add(Label.PROMOTION_FLOW_INACTIVE);
        }

        if (flowDetails.flow != null && flowDetails.flow.Block_Commits__c) {
            result.add(Label.DEPLOYMENT_FLOW_COMMITS_BLOCKED);
        }

        return result;
    }

    private static void deletePreviousUserStoryMetadata(User_Story__c userStory) {
        delete new UserStoriesMetadataSelector().byUserStoryId(new Set<Id>{ userStory.Id });
    }

    private static void saveChangesAsUserStoryMetadata(Request request, User_Story__c userStory) {
        List<User_Story_Metadata__c> changes = new List<User_Story_Metadata__c>();
        for (Change change : request.changes) {
            changes.add(change.toUserStoryMetadata(userStory));
        }

        // Note: False positive, checked permissions before
        upsert changes Unique_ID__c; // NOPMD
    }

    private static JobExecution__c executeCommitJobTemplate(Request request, CreateExecutionRequestData data, User_Story__c userStory) {
        Id contentVersionId = upsertFile(userStory.Id, 'Copado Commit changes.json', JSON.serialize(request.changes, true));
        data.fileWithSelectedChanges(contentVersionId);

        CreateExecution.Request jobRequest = createJobRequest(data, userStory);

        return executeJob(jobRequest);
    }

    // Note: this is the File that the Job will read if/when executed, avoiding the need of any Flow to gather the information
    private static Id upsertFile(Id parentId, String name, String content) {
        deleteExistingFile(parentId);

        return createVersionWithLink(name, content, parentId);
    }

    private static void deleteExistingFile(Id parentId) {
        Set<Id> contentDocumentIds = new Set<Id>();

        for (ContentDocumentLink cdl : new ContentDocumentLinksSelector().byLinkedEntityId(new Set<Id>{ parentId })) {
            contentDocumentIds.add(cdl.ContentDocumentId);
        }

        // Note: False positive since it is file
        delete new ContentDocumentsSelector().byId(contentDocumentIds);
    }

    private static Id createVersionWithLink(String name, String content, Id parentId) {
        ContentVersion cv = new ContentVersion(Title = name, PathOnClient = name, VersionData = Blob.valueOf(content), ContentLocation = 'S');
        // Note: False positive since it is file
        insert cv; // NOPMD

        Id contentDocumentId = new ContentVersionsSelector().byId(new Set<Id>{ cv.Id })[0].ContentDocumentId;

        // Note: False positive since it is file
        insert new ContentDocumentLink(LinkedEntityId = parentId, ContentDocumentId = contentDocumentId, shareType = 'V'); // NOPMD

        return cv.Id;
    }

    private static CreateExecution.Request createJobRequest(CreateExecutionRequestData data, User_Story__c userStory) {
        CreateExecution.Request result = new CreateExecution.Request();
        result.runAfterInstantiation = true;
        result.parentId = data.userStoryCommitId();
        result.pipelineId = userStory.Project__r.Deployment_Flow__c;
        result.templateName = getTemplateName(userStory);
        result.callback = CommitAction.class.getName();
        result.dataJson = JSON.serializePretty(data, true);
        result.sourceId = userStory.Environment__c;

        return result;
    }

    private static String getTemplateName(User_Story__c userStory) {
        String result;

        if (String.isNotBlank(userStory.Environment__r?.CommitJobTemplateOverride__r?.ApiName__c)) {
            result = userStory.Environment__r.CommitJobTemplateOverride__r.ApiName__c;
        } else if (String.isNotBlank(userStory.Project__r?.Deployment_Flow__r?.CommitJobTemplate__r?.ApiName__c)) {
            result = userStory.Project__r.Deployment_Flow__r.CommitJobTemplate__r.ApiName__c;
        } else {
            throw new ApplicationException(Label.TemplateIsMissing);
        }

        return result;
    }

    private static JobExecution__c executeJob(CreateExecution.Request jobRequest) {
        return CreateExecution.execute(new List<CreateExecution.Request>{ jobRequest })[0];
    }

    // INNER

    global with sharing class Request {
        @InvocableVariable(label='User Story Id' description='Commit your changes' required=true)
        global Id userStoryId;

        @InvocableVariable(label='Changes' description='List of changes to commit')
        global List<Change> changes = new List<Change>();

        @InvocableVariable(
            label='Recreate feature branch'
            description='If specified, previous branch and User Story Metadata records previously commited will be deleted. Defaults to false'
        )
        global Boolean recreateFeatureBranch = false;

        @InvocableVariable(
            label='Execute commit'
            description='If set to false, actual commit behaviour will be skipped and only operations in Copado will happen. Likely specified to false when commiting from CLI. Defaults to true'
        )
        global Boolean executeCommit = true;

        @InvocableVariable(
            label='Base branch'
            description='Base branch for the commit. If not provided, a default value is calculated based on User Story, Release, or Pipeline'
        )
        global String baseBranch; // optional, default value calculated

        @InvocableVariable(
            label='Message'
            description='Commit message. If not provided, a default value is calculated based on User Story Name and Title'
        )
        global String message; // optional, default value calculated

        @InvocableVariable(label='JSON Information' description='Additional commit information in JSON format')
        global String jsonInformation; // optional

        @InvocableVariable(label='Commit Id' description='Id of an existing git commit with the changes. Likely specified when commiting from CLI')
        global String commitId; // optional, CLI specific
    }

    // Note: names are short to reduce memory/heap/transmission sizes
    global with sharing class Change {
        global String a; // "action" add, delete, ret-only, full pps, ...
        global String c; // "category": copadodx, vlocity, cpq, ...
        global String m; // "module directory" e.g. force-app/main/default
        global String n; // "name"
        global String t; // "type"
        global String j; // "json additional information"

        // PRIVATE OUTTER

        private User_Story_Metadata__c toUserStoryMetadata(User_Story__c userStory) {
            String metadataApiName = t + '.' + n;
            String uniqueId = uniqueId(userStory.Id);

            return new User_Story_Metadata__c(
                Action__c = a,
                Category__c = c,
                ModuleDirectory__c = m,
                Type__c = t,
                JsonInformation__c = j,
                User_Story__c = userStory.Id,
                Metadata_API_Name__c = n, // Create Name__c later if needed
                Name = (userStory.Name + ' ' + a + ' ' + metadataApiName).left(80),
                Last_Commit_Date__c = System.now(), // needed?
                Unique_ID__c = uniqueId
            );
        }

        // PRIVATE INNER

        private String uniqueId(String userStoryId) {
            String result = userStoryId + ';' + m + ';' + t + ';' + n;
            return getEncodedUniqueIdWhenNeeded(result);
        }

        // Note: Encoding is skipped when not needed due to CPU performance and readability purposes
        private String getEncodedUniqueIdWhenNeeded(String uniqueId) {
            if (uniqueId.length() > 255) {
                uniqueId = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', Blob.valueOf(uniqueId)));
            }
            return uniqueId;
        }
    }

    global with sharing class Response {
        @InvocableVariable(label='Commit changes' description='Commit your changes' required=true)
        global JobExecution__c jobExecution;

        // @InvocableVariable
        // global User_Story_Commit__c userStorycommit;

        // CTOR OUTTER

        private Response(JobExecution__c jobExecution) {
            this.jobExecution = jobExecution;
        }
    }

    private with sharing class CreateExecutionRequestData {
        // Shared variables with Request
        private Id userStoryId;
        private boolean recreateFeatureBranch = false;
        private String baseBranch;
        private String message;
        private String jsonInformation;
        private String commitId;

        // Only used by the Job execution
        private String featureBranchName;
        private Id sourceCredentialId;
        private Id orgCommitId;
        private Id userStoryCommitId;
        private Id fileWithSelectedChanges;

        // CTOR OUTTER

        private CreateExecutionRequestData(User_Story__c userStory, Request request) {
            userStoryId = userStory.Id;
            featureBranchName = 'feature/' + userStory.Name;
            sourceCredentialId = userStory.Org_Credential__c;
            setMessage(request.message, userStory);
            setBaseBranch(request.baseBranch, userStory);
        }

        // PRIVATE OUTTER

        private CreateExecutionRequestData createCommitRecords() {
            Git_Org_Commit__c orgCommit = new Git_Org_Commit__c(
                Commit_Date__c = datetime.now(),
                Commit_Message__c = message.left(255),
                Org__c = sourceCredentialId,
                Status__c = 'Pending'
            );
            // Note: False positive, checked permissions before
            insert orgCommit; // NOPMD
            orgCommitId = orgCommit.Id;

            User_Story_Commit__c userStoryCommit = new User_Story_Commit__c(
                Snapshot_Commit__c = orgCommit.Id,
                User_Story__c = userStoryId,
                Name = message.left(80)
            );
            // Note: False positive, checked permissions before
            insert userStoryCommit; // NOPMD
            userStoryCommitId = userStoryCommit.Id;

            return this;
        }

        private void fileWithSelectedChanges(Id contentVersionId) {
            fileWithSelectedChanges = contentVersionId;
        }

        private Id userStoryCommitId() {
            return userStoryCommitId;
        }

        // PRIVATE INNER

        private void setMessage(String message, User_Story__c userStory) {
            if (String.isNotBlank(message)) {
                this.message = message;
            } else {
                this.message = String.format('[{0}] {1}', new List<Object>{ userStory.Name, userStory.User_Story_Title__c });
            }
        }

        private void setBaseBranch(String branchName, User_Story__c userStory) {
            if (String.isNotBlank(branchName)) {
                baseBranch = branchName;
            } else if (String.isNotBlank(userStory.Base_Branch__c)) {
                baseBranch = userStory.Base_Branch__c;
            } else if (String.isNotBlank(userStory.Release__r.Base_Branch__c)) {
                baseBranch = userStory.Release__r.Base_Branch__c;
            } else if (String.isNotBlank(userStory.Project__r.Deployment_Flow__r.Main_Branch__c)) {
                baseBranch = userStory.Project__r.Deployment_Flow__r.Main_Branch__c;
            } else {
                baseBranch = '';
            }
        }
    }
}