public with sharing class RunDeployJobTemplateHandler extends DeployJobTemplateHelper {
    // PUBLIC

    @AuraEnabled
    public static Boolean validate(Id recordId){
        return isPromotedUserStoriesCreated(recordId); 
    }

    @AuraEnabled
    public static Boolean promoteJobAlreadyExecuted(Id recordId){
        return isPromoteJobExecutionCreated(recordId); 
    }

    @AuraEnabled
    public static Boolean deploymentJobAlreadyExecuted(Id recordId){
        return isDeploymentJobExecutionCreated(recordId); 
    }

    @AuraEnabled
    public static void execute(Id recordId){
        List<PromotionDeployAction.Request> requests = new List<PromotionDeployAction.Request>();
        PromotionDeployAction.Request request = new PromotionDeployAction.Request();
        request.promotionId = recordId;
        request.executeDeployment = true;
        requests.add(request);

        PromotionDeployAction.deploy(requests);
    }

    @AuraEnabled
    public static void executeOutstanding(Id recordId, Boolean runAllSteps) {
        // TODO once we have a run outstanding parameter in deployaction class move the logic there
        updatePromotion(recordId, 'In Progress');
        Deployment__c deployment = new DeploymentsSelector().byPromotionId(recordId);
        if(deployment != null) {
            runOutstandingJobs(new JobExecutionsSelector().byDeploymentId(deployment.Id).Id, runAllSteps);
        }      
    }
}