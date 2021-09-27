public with sharing class RunPromoteJobTemplateHandler extends DeployJobTemplateHelper {
    
    // PUBLIC

    @AuraEnabled
    public static Boolean validate(Id recordId){
        return isPromotedUserStoriesCreated(recordId); 
    }

    @AuraEnabled
    public static Boolean jobAlreadyExecuted(Id recordId){
        return isPromoteJobExecutionCreated(recordId); 
    }

    @AuraEnabled
    public static void execute(Id recordId){
        getPromotionDetails(recordId);
        prepareJobParameters();
        deploy();
    }
 
    @AuraEnabled
    public static void executeOutstanding(Id recordId, Boolean runAllSteps) {
        updatePromotion(recordId, 'In Progress');
        runOutstandingJobs(new JobExecutionsSelector().byPromotionId(recordId).Id, runAllSteps);
    }
}