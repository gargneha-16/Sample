@SuppressWarnings('PMD')
global with sharing class PromotionDeployAction extends PromoteActionService implements JobExecutionCallback {
    // TODO: Remove this comment
    private static CreateExecutionRequestData requestData;

    global class Request {
        @InvocableVariable(required=true label='Promotion Id' description='Id of the Promotion record. Copado will create a new deployment with the parameter values provided.')
        global Id promotionId;
        @InvocableVariable(label='Execute Deployment' description='Include this parameter if you want to run the deploy job template.')
        global boolean executeDeployment;
        @InvocableVariable(label='Deployment Dry Run' description='Include this parameter if you want to perform a validation-only deployment.')
        global boolean deploymentDryRun; // NOTE: this is "validate only", but more generic for other technologies
        @InvocableVariable(label='Other Information' description='Additional information that can be passed for the job execution in JSON format')
        global String otherInformation; // "other information" in json, additional values associated with this commit
    }

    global with sharing class Response {
        @InvocableVariable
        global JobExecution__c jobExecution;
    }


    // GLOBAL

    @InvocableMethod(label='Run a Copado promotion deployment' description='' category='Copado Multi-Cloud')
    global static List<Response> deploy(List<Request> requests) {
        requestData = new CreateExecutionRequestData();

        // Note: No need of bulkification, so keep it simple
        Request request = requests[0];
        requestData.promotionId = request.promotionId != null ? request.promotionId : null;
        requestData.executeDeployment = request.executeDeployment != null ? request.executeDeployment : false;
        requestData.deploymentDryRun = request.deploymentDryRun != null ? request.deploymentDryRun : false;
        requestData.otherInformation = request.otherInformation != null ? request.otherInformation : null;

        getPromotionDetails(requestData);

        Boolean updatePromotionStatus = requestData.executeDeployment || requestData.deploymentDryRun;
        if(requestData.promotion.Status__c != PromoteActionService.IN_PROGRESS && updatePromotionStatus) {
            PromotionTriggerHelper.bypassPromotionTrigger = true;
            updatePromotion(requestData.promotionId, PromoteActionService.IN_PROGRESS);
        }

        if(isDeploymentJobExecutionCreated(requestData)) {
            if(requestData.deployment != null) {
                Id jobExecutionId = new JobExecutionsSelector().byDeploymentId(requestData.deployment.Id).Id;
                updateJobExecutionDataJson(jobExecutionId, requestData);
                runOutstandingJobs(jobExecutionId);
            }
        } else {
            insertDeploymentWithDestinations();

            // TODO: the order of the user stories in the promotion needs to be configurable
            List<Promoted_User_Story__c> promotedUserStories = new PromotedUserStoriesSelector().byPromotionId(new Set<Id>{ requestData.promotion.Id });
            List<JobStep__c> allSteps = new JobStepsSelector().byUserStoryId( userStoryIds(promotedUserStories) );
            List<JobStep__c> preSteps = filterBySequence(allSteps, 'before');
            List<JobStep__c> postSteps = filterBySequence(allSteps, 'after');

            populateUserStoryParameters(requestData, promotedUserStories);
            populateChangeParameters(requestData);
            populateFileParameters(requestData, requestData.deployment.Id, 'Copado Deploy changes.json');

            String templateName = deploymentTemplateAPIName();
            String parentId = requestData.deployment.Id;
            String callbackClass = Settings.ns.replace('__', '.') + 'PromotionDeployAction';
            requestData.promotionBranchName = 'promotion/' + requestData.promotion.Name;
            requestData.destinationBranchName = destinationBranchName(requestData.promotion);

            CreateExecution.execute( asRequests(requestData, templateName, parentId, callbackClass, preSteps, postSteps) );
        }

        Response responseRecord = new Response();
        responseRecord.jobExecution = new JobExecutionsSelector().byDeploymentId(requestData.deploymentId);
        return new List<Response>{ responseRecord };
    }

    // Callback after the job finishes
    global void execute(JobExecution__c job, String status) {
        requestData = (CreateExecutionRequestData)JSON.deserialize(job.DataJson__c, CreateExecutionRequestData.class);
        // TODO: ... notify the User? TBD how, or which service
        String promotionStatus = status == PromoteActionService.SUCCESSFUL ? PromoteActionService.COMPLETED : PromoteActionService.COMPLETED_WITH_ERRORS;
        String deploymentStatus = status == PromoteActionService.SUCCESSFUL ? 'Completed Successfully' : 'Completed with Errors';
        Destination_Org__c destinationOrg = getDestinationOrgDetails(job.ParentId__c);
        List<SObject> records = new List<SObject> {
            getPromotion(destinationOrg.Deployment__r.Promotion__c, promotionStatus, requestData.deploymentDryRun),
            getDestinationOrg(destinationOrg.Id, deploymentStatus),
            getDeployment(job.ParentId__c, deploymentStatus)
        };

        fflib_SObjectDomain.getTriggerEvent(DeploymentTriggerHandler.class).disableAll();
        fflib_SObjectDomain.getTriggerEvent(DestinationOrgTriggerHandler.class).disableAll();

        if(requestData.deploymentDryRun) {
           PromotionTriggerHelper.resetUserStories = false; 
        }

        update Security.stripInaccessible(AccessType.UPDATABLE, records).getRecords();

        fflib_SObjectDomain.getTriggerEvent(DestinationOrgTriggerHandler.class).enableAll();
        fflib_SObjectDomain.getTriggerEvent(DeploymentTriggerHandler.class).enableAll();
    }


    // PRIVATE

    private static void insertDeploymentWithDestinations() {
        fflib_SObjectDomain.getTriggerEvent(DestinationOrgTriggerHandler.class).disableAll();
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Destination_Org__c>{ destination() });
        insert decision.getRecords();
        fflib_SObjectDomain.getTriggerEvent(DestinationOrgTriggerHandler.class).enableAll();
    }

    private static Destination_Org__c destination() {
        insertDeployment();
        return new Destination_Org__c(
            Deployment__c = requestData.deployment.Id,
            To_Org__c = requestData.promotion.Destination_Org_Credential__c,
            Status__c = PromoteActionService.IN_PROGRESS
        );
    }

    private static void insertDeployment() {
        fflib_SObjectDomain.getTriggerEvent(DeploymentTriggerHandler.class).disableAll();
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Deployment__c>{ deployment() });
        insert decision.getRecords();
        fflib_SObjectDomain.getTriggerEvent(DeploymentTriggerHandler.class).enableAll();

        requestData.deployment = (Deployment__c) (decision.getRecords().get(0));
        requestData.deploymentId = requestData.deployment.Id;
        shareDeploymentWithPromotionOwner();
    }

    private static Deployment__c deployment() {
        String advancedDeploymentRecordId = Schema.Sobjecttype.Deployment__c.getRecordTypeInfosByDeveloperName().get('Advanced_multi_step').getRecordTypeId();

        return new Deployment__c(
            RecordTypeId = advancedDeploymentRecordId,
            Name = requestData.promotion.Name,
            Status__c = 'In progress',
            Promotion__c = requestData.promotion.Id,
            From_Org__c = requestData.promotion.Source_Org_Credential__c
        );
    }

    private static void shareDeploymentWithPromotionOwner() {
        Deployment__Share deploymentShare = new Deployment__Share();
        deploymentShare.ParentId = requestData.deployment.Id;
        deploymentShare.UserOrGroupId = requestData.promotion.OwnerId;
        deploymentShare.AccessLevel = 'Read';
        deploymentShare.RowCause = Schema.Deployment__Share.RowCause.Manual;
        Database.insert(deploymentShare, false);
    }

    private static String deploymentTemplateAPIName() {
        String overridenTemplate = requestData.promotion.Destination_Environment__r.Deployment_Job_Template_Override__r?.ApiName__c;
		
        String templateApiName = '';
        if(requestData.promotion.Project__c != null) {
            templateApiName = requestData.promotion.Project__r.Deployment_Flow__r.Deployment_Job_Template__r.ApiName__c;
        } else if(requestData.promotion.Release__c != null) {
            templateApiName = requestData.promotion.Release__r.Project__r.Deployment_Flow__r.Deployment_Job_Template__r.ApiName__c;
        }
        
        return (overridenTemplate != null) ? overridenTemplate : templateApiName;
    }

    private static List<JobStep__c> filterBySequence(List<JobStep__c> steps, String executionSequence) {
        List<JobStep__c> result = new List<JobStep__c>();

        for (JobStep__c step : steps) {
            if(step.ExecutionSequence__c == executionSequence) {
                result.add(step);
            }
        }

        return result;
    }

    private static Set<Id> userStoryIds(List<Promoted_User_Story__c> promotedUserStories) {
        Set<Id> result = new Set<Id>();

        for(Promoted_User_Story__c promotedUserStory : promotedUserStories) {
            result.add(promotedUserStory.User_Story__c);
        }

        return result;
    }


    // EXECUTED IN CALLBACK

    private Promotion__c getPromotion(Id promotionId, String status, Boolean deploymentDryRun) {
        Boolean promotionMergedAndDeployed = status == COMPLETED && !deploymentDryRun;
        return new Promotion__c(Id = promotionId, Status__c = status, Completed__c = promotionMergedAndDeployed);
    }

    private Deployment__c getDeployment(Id deploymentId, String status) {
        return new Deployment__c(Id = deploymentId, Status__c = status);
    }

    private Destination_Org__c getDestinationOrgDetails(Id deploymentId) {
        return [SELECT Id, Status__c, Deployment__c, Deployment__r.Promotion__c FROM Destination_Org__c WHERE Deployment__c = :deploymentId WITH SECURITY_ENFORCED LIMIT 1];
    }

    private Destination_Org__c getDestinationOrg(Id destinationId, String status) {
        return new Destination_Org__c(Id = destinationId, Status__c = status);
    }
}