@SuppressWarnings('PMD')
public with sharing virtual class PromoteActionService {
    // TODO: Remove this comment

    public static final String IN_PROGRESS = 'In Progress';
    public static final String SUCCESSFUL = 'Successful';
    public static final String COMPLETED = 'Completed';
    public static final String COMPLETED_WITH_ERRORS = 'Completed with errors';

    // PUBLIC

    public static void populateUserStoryParameters(CreateExecutionRequestData requestData, List<Promoted_User_Story__c> promotedUserStories) {
        requestData.userStoryIds = new List<Id>();
        requestData.userStoryBranches = new List<String>();
        for(Promoted_User_Story__c promotedUserStory : promotedUserStories) {
            requestData.userStoryIds.add(promotedUserStory.User_Story__c);
            requestData.userStoryBranches.add('feature/' + promotedUserStory.User_Story__r.Name);
        }
    }

    public static void populateChangeParameters(CreateExecutionRequestData requestData) {
        // read all the User_Story_Metadata objects of all the user stories, make it a unique list
        // and save it into requestData.changes
        requestData.changes = new List<Change>();
        List<User_Story_Metadata__c> userStoryMetadatas = [SELECT Metadata_API_Name__c, Type__c, Action__c, 
                                                           ModuleDirectory__c, Category__c, JsonInformation__c
                                                           FROM User_Story_Metadata__c 
                                             WHERE User_Story__c IN :requestData.userStoryIds
                                             WITH SECURITY_ENFORCED
                                             ORDER BY CreatedDate DESC LIMIT 8000];
        for(User_Story_Metadata__c userStoryMetadata : userStoryMetadatas) {
            Change changeItem = new Change(userStoryMetadata.Metadata_API_Name__c, 
                                           userStoryMetadata.Type__c, 
                                           userStoryMetadata.ModuleDirectory__c, 
                                           userStoryMetadata.Action__c, 
                                           userStoryMetadata.Category__c, 
                                           userStoryMetadata.JsonInformation__c);
            requestData.changes.add(changeItem);
        }
    }

    public static void populateFileParameters(CreateExecutionRequestData requestData, Id parentId, String fileName) {
        // THIS is the File that the  Job will read if/when executed, avoiding the need of any Flow to gather the information
        String changesJson = Json.serialize(requestData.changes, true);
        requestData.changes = null; // remove the changes from the request
        ContentVersion contentVersionRecord = upsertFileWithParent(parentId, fileName, changesJson);
        requestData.fileWithSelectedChanges = contentVersionRecord.Id;
    }

    public static Boolean isDeploymentJobExecutionCreated(CreateExecutionRequestData requestData) {
        requestData.deployment = new DeploymentsSelector().byPromotionId(requestData.promotionId);
        return requestData.deployment != null && (new JobExecutionsSelector().byDeploymentId(requestData.deployment.Id)) != null;
    }

    public static void updatePromotion(Id promotionId, String status) {
        List<SObject> records = new List<SObject> {
            new Promotion__c(Id = promotionId, Status__c = status)
        };

        update Security.stripInaccessible(AccessType.UPDATABLE, records).getRecords();
    }

    public static void updateJobExecutionDataJson(Id jobExecutionId, CreateExecutionRequestData requestData) {
        requestData.promotion = null;
        requestData.deployment = null;

        List<SObject> records = new List<SObject> {
            new JobExecution__c(Id = jobExecutionId, DataJson__c = Json.serializePretty(requestData, true))
        };

        update Security.stripInaccessible(AccessType.UPDATABLE, records).getRecords();
    }

    public static void runOutstandingJobs(Id jobId) {
        RunJob.Request request = new RunJob.Request();
        request.jobId = jobId;
        request.allSteps = true;

        RunJob.execute(new List<RunJob.Request>{ request });
    }

    public static void getPromotionDetails(CreateExecutionRequestData requestData) {
        List<Promotion__c> promotions = new PromotionsSelector().onlyPromotionsDetailByIds(new Set<Id>{ requestData.promotionId });
        requestData.promotion = promotions.isEmpty() ? new Promotion__c() : promotions[0];
    }

    public static List<CreateExecution.Request> asRequests(CreateExecutionRequestData requestData, String templateName, Id parentId, String callbackClass, List<JobStep__c> preStep, List<JobStep__c> postStep) {
        CreateExecution.Request requestRecord = new CreateExecution.Request();
        requestRecord.templateName = templateName;
        requestRecord.parentId = parentId;
        requestRecord.sourceId = requestData.promotion.Source_Environment__c;
        requestRecord.destinationId = requestData.promotion.Destination_Environment__c;
        requestRecord.callback = callbackClass;
        requestRecord.runAfterInstantiation = requestData.executePromotion != null ? requestData.executePromotion : requestData.executeDeployment;
        requestRecord.preSteps = preStep;
        requestRecord.postSteps = postStep;

        requestData.promotion = null;
        requestData.deployment = null;

        requestRecord.dataJson = Json.serializePretty(requestData, true);

        return new List<CreateExecution.Request>{ requestRecord };
    }

    public static List<CreateExecution.Request> asRequests(CreateExecutionRequestData requestData, String templateName, Id parentId, String callbackClass) {
        return asRequests(requestData, templateName, parentId, callbackClass, null, null);
    }

    public static String destinationBranchName(Promotion__c promotion) {
        String pipelineId = pipeline(promotion);
        String branch = [SELECT Id, Branch__c FROM Deployment_Flow_Step__c WHERE Deployment_Flow__c = :pipelineId AND Source_Environment__c = :promotion.Destination_Environment__c WITH SECURITY_ENFORCED]?.Branch__c;
        if(String.isBlank(branch)) {
            branch = [SELECT Id, Main_Branch__c FROM Deployment_Flow__c WHERE Id = :pipelineId WITH SECURITY_ENFORCED]?.Main_Branch__c;
        }
        return branch;
    }


    // PRIVATE 

    private static ContentVersion upsertFileWithParent(Id parentId, String name, String content) {
        deletePreviousFileWithParent(parentId);
                
        // create new file
        ContentVersion contentVersionRecord = new ContentVersion();
        contentVersionRecord.ContentLocation = 'S'; // 'S' = a Salesforce File
        contentVersionRecord.VersionData = Blob.valueOf(content);
        contentVersionRecord.Title = name;
        contentVersionRecord.PathOnClient = contentVersionRecord.Title;
        insert contentVersionRecord;
        
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionRecord.Id].ContentDocumentId;
        ContentDocumentLink contentDocumentLinkRecord = new ContentDocumentLink();
        contentDocumentLinkRecord.LinkedEntityId = parentId;
        contentDocumentLinkRecord.ContentDocumentId = contentDocumentId;
        contentDocumentLinkRecord.shareType = 'V';
        insert contentDocumentLinkRecord;
        
        return contentVersionRecord;
    }

    private static void deletePreviousFileWithParent(Id parentId) {
        // TODO first check iof we cvan delete the file for different owner. Also check if we need to SOQL with security enforced.
        // TODO not sure if we need to check OLS for content version

        // delete previous file(s) with the same name and parentId, if any
        List<ContentDocumentLink> contentDocumentLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :parentId LIMIT 100];
        if(!contentDocumentLinks.isEmpty()) {
            Set<Id> contentDocumentLinkIds = new Set<Id>();
            for(ContentDocumentLink contentDocumentLinkRecord : contentDocumentLinks) {
                contentDocumentLinkIds.add(contentDocumentLinkRecord.ContentDocumentId);
            }
            List<ContentDocument> existingFiles = [SELECT Id FROM ContentDocument WHERE Id IN :contentDocumentLinkIds];
            delete existingFiles;
        }
    }

    private static String pipeline(Promotion__c promotion) {
        String pipelineId = '';
        if(promotion.Project__c != null) {
            pipelineId = promotion.Project__r.Deployment_Flow__c;
        } else if(promotion.Release__c != null) {
            pipelineId = promotion.Release__r.Project__r.Deployment_Flow__c;
        }
        return pipelineId;
    }


    // WRAPPER 

    public class CreateExecutionRequestData {
        // Common variables for both Promote and Deploy action
        public Id promotionId;
        public Boolean deploymentDryRun; 
        public Boolean executeDeployment;
        public String otherInformation;

        // Variables for Promote action
        public Id sourceEnvironmentId;
        public Boolean isBackPromotion;
        public Id projectId;
        public Boolean executePromotion;

        // Only used by the Job execution for both action
        public List<Change> changes; // list of all changes of each user story
        public Promotion__c promotion;
        public String destinationBranchName;
        public String promotionBranchName;
        public Id fileWithSelectedChanges;
        public List<Id> userStoryIds;

        // Only used by the Job execution for Deploy Action
        public Id deploymentId;
        public Deployment__c deployment;

        // Only used by the Job execution for Promote Action
        public Id sourceCredentialId;
        public Id destinationCredentialId;
        public List<String> userStoryBranches = new List<String>();
        public List<Promotion__c> promotions;
    }

    // NOTE: names are short to reduce memory/heap/transmission sizes
    public class Change {
        @InvocableVariable(required=true)
        public String n; // "name"

        @InvocableVariable
        public String t; // "type"

        @InvocableVariable
        public String m; // "module directory"

        @InvocableVariable(required=true)
        public String a; // "action" add, delete, retrieve-only, full pps, "deleteCascade"

        @InvocableVariable
        public String c; // optional, not used right now, "category" of this item: copadodx, vlocity, cpq, ...

        @InvocableVariable
        public String j; // "json additional information"... other values associated with this File

        public Change(String n, String t, String m,  String a, String c, String j) {
            this.n = n;
            this.t = t;
            this.m = m;
            this.a = a;
            this.c = c;
            this.j = j;
        }
    }
}