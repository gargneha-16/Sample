public with sharing class RunPromoteAndDeployJobTemplateHandler extends DeployJobTemplateHelper {

    // PUBLIC

    @AuraEnabled
    public static Boolean validate(Id recordId){
        return isPromotedUserStoriesCreated(recordId); 
    }

    @AuraEnabled
    public static Boolean deploymentJobAlreadyExecuted(Id recordId){
        return isDeploymentJobExecutionCreated(recordId); 
    }
    
    @AuraEnabled
    public static void execute(Id recordId){
        if(isPromoteJobExecutionCreated(recordId)) {
            RunDeployJobTemplateHandler.execute(recordId);
        } else {
            getPromotionDetails(recordId);
            prepareJobParameters();
            run();
        }
    }

    @AuraEnabled
    public static void executeOutstanding(Id recordId, Boolean runAllSteps) {
        
        JobExecution__c promoteJobExecution = new JobExecutionsSelector().byPromotionId(recordId);
        updatePromotion(recordId, 'In Progress');

        if(runAllSteps || promoteJobExecution.Status__c != 'Successful') {
            runOutstandingJobs(promoteJobExecution.Id, runAllSteps);       
        } else {
            Deployment__c deployment = new DeploymentsSelector().byPromotionId(recordId);
            if(deployment != null) {
                runOutstandingJobs(new JobExecutionsSelector().byDeploymentId(deployment.Id).Id, runAllSteps);
            } 
        }      
    }
}