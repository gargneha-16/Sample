@SuppressWarnings('PMD')
global with sharing class PromoteAction extends PromoteActionService implements JobExecutionCallback {
    private static final String PROMOTED_USER_STORY = 'Promoted User Story: ';
    private static final String BACK_PROMOTED_USER_STORY = 'Back Promoted User Story: ';
    private static CreateExecutionRequestData requestData;
    
    global class Request {
        @InvocableVariable(label='Promotion Id' description='Id of the Promotion record. If it is not defined, Copado will create a new promotion with the parameter values provided.')
        global Id promotionId;
        @InvocableVariable(label='User Story Ids' description='Ids of the user stories to be included in the promotion.')
        global List<Id> userStoryIds = new List<Id>();
        @InvocableVariable(label='Execute Promotion' description='Include this parameter if you want to run the promote job template.')
        global Boolean executePromotion;
        @InvocableVariable(label='Execute Deployment' description='Include this parameter if you want to run the deploy job template after the promote job template execution.')
        global Boolean executeDeployment; // this is for promote+deplos US, validate US, and validate promotion
        @InvocableVariable(label='Deployment Dry Run' description='Include this parameter if you want to perform a validation-only deployment.')
        global Boolean deploymentDryRun; // NOTE: this is "validate only", but more generic for other technologies
        @InvocableVariable(label='Other Information' description='Additional information that can be passed for the job execution in JSON format')
        global String otherInformation; // "other information" in json, additional values associated with this commit
        @InvocableVariable(label='Source Environment Id' description='Id of the promotion’s source environment. Copado will use this parameter to populate the destination environment if no promotion Id is specified.')
        global Id sourceEnvironmentId;
        @InvocableVariable(label='Project Id' description='Id of the Project record that will be used to define the pipeline details and pipeline connections.')
        global Id projectId;
        @InvocableVariable(label='Back Promotion' description='Include this parameter if the promotion that will be executed is a back-promotion.')
        global Boolean isBackPromotion;
    }

    global class Response {
        @InvocableVariable
        global JobExecution__c jobExecution;
        @InvocableVariable
        global Promotion__c promotion;
    }

    
    // GLOBAL

    @InvocableMethod(label='Run a Copado promote' description='' category='Copado Multi-Cloud')
    global static List<Response> promote(List<Request> requests) {
        requestData = new CreateExecutionRequestData();
        // Note: No need of bulkification, so keep it simple
        Request request = requests[0];
        requestData.promotionId = request.promotionId != null ? request.promotionId : null;
        requestData.executePromotion = request.executePromotion != null ? request.executePromotion : false;
        requestData.executeDeployment = request.executeDeployment != null ? request.executeDeployment : false;
        requestData.deploymentDryRun = request.deploymentDryRun != null ? request.deploymentDryRun : false;
        requestData.otherInformation = request.otherInformation != null ? request.otherInformation : null;

        if(String.isEmpty(request.promotionId)) {
            requestData.userStoryIds = request.userStoryIds;
            if(requestData.userStoryIds.isEmpty()) {
                // TODO throw an error and return message 
                // throw error
            }
            Promotion__c promotion = createPromotionRecord(request);
            requestData.promotion = insertPromotions( new List<Promotion__c> { promotion })[0];
            requestData.promotionId = requestData.promotion.Id;

            // Create the Promoted User Stories object with the data in the requestData
            List<Promoted_User_Story__c> promotedUserStories = new List<Promoted_User_Story__c>();
            for(User_Story__c userStory : userStories(requestData.userStoryIds)) {
                promotedUserStories.add(createPromotedUserStoryRecord(requestData.promotion, userStory));
            }
            insertPromotedUserStories(promotedUserStories);

            processPromotion();
            processJobExecution();
        } else {
            requestData.promotionId = request.promotionId;

            JobExecution__c jobExecution = new JobExecutionsSelector().byPromotionId(requestData.promotionId);
            processPromotion();
            if(jobExecution != null) {
                updateJobExecutionDataJson(jobExecution.Id, requestData);
                runOutstandingJobs(jobExecution.Id);
            } else {
                processJobExecution();
            }
        }

        Response responseRecord = new Response();
        responseRecord.jobExecution = new JobExecutionsSelector().byPromotionId(requestData.promotionId);
        responseRecord.promotion = requestData.promotion;
        return new List<Response>{ responseRecord };
    }

    // Callback after the job finishes
    global void execute(JobExecution__c job, String status) {
        requestData = (CreateExecutionRequestData)JSON.deserialize(job.DataJson__c, CreateExecutionRequestData.class);
        getPromotionDetails(requestData);
        Boolean jobIsSuccess = status == PromoteActionService.SUCCESSFUL;
        if(jobIsSuccess && isDeploymentJobExecutionCreated(requestData) && requestData.executeDeployment) {
            PromotionTriggerHelper.bypassPromotionTrigger = true;
            updatePromotion(job.ParentId__c, PromoteActionService.IN_PROGRESS);

            Deployment__c deployment = new DeploymentsSelector().byPromotionId(job.ParentId__c);
            if(deployment != null) {
                Id jobExecutionId = new JobExecutionsSelector().byDeploymentId(deployment.Id).Id;
                updateJobExecutionDataJson(jobExecutionId, requestData);
                runOutstandingJobs(jobExecutionId);
            } 
        } else {
            PromotionTriggerHelper.resetUserStories = false;
            String promotionStatus = jobIsSuccess ? PromoteActionService.COMPLETED : PromoteActionService.COMPLETED_WITH_ERRORS;
            updatePromotion(job.ParentId__c, promotionStatus);
        }  
    }


    // PUBLIC 

    public static List<Promotion__c> insertPromotions(List<Promotion__c> promotions) {
        PromotionTriggerHelper.createJobExecution = false;
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, promotions);
        insert decision.getRecords();
        return (List<Promotion__c>) decision.getRecords();
    }

    public static Promotion__c createPromotionRecord(Request request) {
        // Create the Promotion object with the data in the request
        Promotion__c promotion = new Promotion__c();
        promotion.Project__c = request.projectId;
        promotion.Back_Promotion__c = request.isBackPromotion;
        
        // PromotionTriggerHelper.setDestinationOrgFromFlow will populate necessary fields
        // TODO: move the logic in a helper class
        if(request.isBackPromotion) {
            promotion.Destination_Environment__c = request.sourceEnvironmentId;
        } else {
            promotion.Source_Environment__c = request.sourceEnvironmentId;
        }
        return promotion;
    }

    public static Promoted_User_Story__c createPromotedUserStoryRecord(Promotion__c promotion, User_Story__c userStory) {
        Promoted_User_Story__c promotedUserStory = new Promoted_User_Story__c();
        promotedUserStory.Name = promotedUserStoryName(promotion, userStory.Name);
        promotedUserStory.Promotion__c = promotion.Id;
        promotedUserStory.User_Story__c = userStory.Id;
        return promotedUserStory;
    }

    public static void insertPromotedUserStories(List<Promoted_User_Story__c> promotedUserStories) {
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, promotedUserStories);
        insert decision.getRecords();
    }

    
    // PRIVATE 

    private static List<User_Story__c> userStories(List<Id> userStoryIds) {
        return [SELECT Id, Name FROM User_Story__c WHERE Id IN :userStoryIds WITH SECURITY_ENFORCED];
    }

    private static String promotedUserStoryName(Promotion__c promotion, String userStoryName) {
        return promotion.Back_Promotion__c ? BACK_PROMOTED_USER_STORY + userStoryName : PROMOTED_USER_STORY + userStoryName;
    }
    
    private static void processPromotion() {
        getPromotionDetails(requestData);
        // TODO: the order of the user stories in the promotion needs to be configurable
        List<Promoted_User_Story__c> promotedUserStories = new PromotedUserStoriesSelector().byPromotionId(new Set<Id>{ requestData.promotionId });
        
        requestData.isBackPromotion = !promotedUserStories.isEmpty() ? promotedUserStories[0].Promotion__r.Back_Promotion__c : false;
        requestData.sourceCredentialId = !promotedUserStories.isEmpty() ? promotedUserStories[0].Promotion__r.Source_Org_Credential__c : null;
        requestData.destinationCredentialId = !promotedUserStories.isEmpty() ? promotedUserStories[0].Promotion__r.Destination_Org_Credential__c : null;
        
        populateUserStoryParameters(requestData, promotedUserStories);
        populateChangeParameters(requestData);
    }
    
    private static void executePromoteJobTemplate() {
        populateFileParameters(requestData, requestData.promotionId, 'Copado Promotion changes.json');
        String templateName = promotionTemplateApiName(requestData.promotion);
        String parentId = requestData.promotionId;
        String callbackClass = Settings.ns.replace('__', '.') + 'PromoteAction';
        requestData.promotionBranchName = 'promotion/' + requestData.promotion.Name;
        requestData.destinationBranchName = destinationBranchName(requestData.promotion);
        CreateExecution.execute( asRequests(requestData, templateName, parentId, callbackClass) );
        // TODO: volume options
    }

    private static String promotionTemplateApiName(Promotion__c promotion) {
        String overridenTemplate = promotion.Destination_Environment__r.Promotion_Job_Template_Override__r?.ApiName__c;
        
        String templateApiName = '';
        if(promotion.Project__c != null) {
            templateApiName = promotion.Project__r.Deployment_Flow__r.Promotion_Job_Template__r.ApiName__c;
        } else if(promotion.Release__c != null) {
            templateApiName = promotion.Release__r.Project__r.Deployment_Flow__r.Promotion_Job_Template__r.ApiName__c;
        }
        return (overridenTemplate != null) ? overridenTemplate : templateApiName;
    }

    private static void createDeploymentAndJobExecution() {
        List<PromotionDeployAction.Request> requests = new List<PromotionDeployAction.Request>();
        PromotionDeployAction.Request request = new PromotionDeployAction.Request();
        request.promotionId = requestData.promotionId;
        request.executeDeployment = !requestData.executePromotion ? requestData.executePromotion : requestData.executeDeployment;
        request.deploymentDryRun = requestData.deploymentDryRun;
        request.otherInformation = requestData.otherInformation;
        requests.add(request);

        PromotionDeployAction.deploy(requests);
    }

    private static void updatePromotionForExecutionFields(Id promotionId, Id promotionJobExecution, Id deploymentJobExecution) {
        List<SObject> records = new List<SObject> {
            new Promotion__c(Id = promotionId, Last_Promotion_Execution_Id__c = promotionJobExecution, Last_Deployment_Execution_Id__c = deploymentJobExecution)
        };

        PromotionTriggerHelper.bypassPromotionTrigger = true;
        update Security.stripInaccessible(AccessType.UPDATABLE, records).getRecords();
    }

    private static void processJobExecution() {
        executePromoteJobTemplate();
        createDeploymentAndJobExecution();

        Id promotionJobExecutionId = new JobExecutionsSelector().byPromotionId(requestData.promotionId).Id;
        Deployment__c deployment = new DeploymentsSelector().byPromotionId(requestData.promotionId);
        Id deploymentJobExecutionId = new JobExecutionsSelector().byDeploymentId(deployment.Id).Id;
        updatePromotionForExecutionFields(requestData.promotionId, promotionJobExecutionId, deploymentJobExecutionID);
    }
}