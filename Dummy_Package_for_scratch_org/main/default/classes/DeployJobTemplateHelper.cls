public with sharing virtual class DeployJobTemplateHelper {
    public static Promotion__c promotion;
    public static PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters;
    private static Deployment__c deployment;
    private static final String NO_TEST_RUN = 'NoTestRun';
    public static final String IN_PROGRESS = 'In Progress';
    
    // PUBLIC

    public static Boolean isPromotedUserStoriesCreated(Id promotionId) {
        return (new PromotedUserStoriesSelector().byPromotionId(new Set<Id>{ promotionId })).size() > 0;
    }

    public static Boolean isPromoteJobExecutionCreated(Id promotionId) {
        String jobExecutionId = new JobExecutionsSelector().byPromotionId(promotionId).Id;
        return isResultCreatedForStep(jobExecutionId);
    }

    public static Boolean isDeploymentJobExecutionCreated(Id promotionId) {
        Deployment__c deployment = new DeploymentsSelector().byPromotionId(promotionId);
        String jobExecutionId = new JobExecutionsSelector().byDeploymentId(deployment.Id).Id;
        return isResultCreatedForStep(jobExecutionId);
    }

    public static void getPromotionDetails(Id promotionId) {
        List<Promotion__c> promotions = new PromotionsSelector().onlyPromotionsDetailByIds(new Set<Id>{ promotionId });
        promotion = promotions.isEmpty() ? new Promotion__c() : promotions[0];
    }

    public static void prepareJobParameters() {
        jobParameters = new PipelineManagerExtension.PipelineOperationsServiceJobsParameters();
        jobParameters.promotionWrappers = new List<PipelineManagerExtension.PromotionWrapper> { new PipelineManagerExtension.PromotionWrapper(promotion, NO_TEST_RUN, true) };
        jobParameters.testLevelValue = NO_TEST_RUN;
        jobParameters.isCheckOnly = false;
    }

    public static void deploy() {
        JobTemplateService controller = new JobTemplateService();
        controller.deploy(jobParameters);
    }

    public static void run() {
        JobTemplateService controller = new JobTemplateService();
        controller.commonOperations(jobParameters, true, false);
    }

    public static void updatePromotion(Id promotionId, String status) {
        List<SObject> records = new List<SObject> {
            new Promotion__c(Id = promotionId, Status__c = status)
        };

        update Security.stripInaccessible(AccessType.UPDATABLE, records).getRecords();
    }

    public static void runOutstandingJobs(Id jobId, Boolean outstanding) {
        RunJob.Request request = new RunJob.Request();
        request.jobId = jobId;
        request.allSteps = outstanding;

        RunJob.execute(new List<RunJob.Request>{ request });
    }


    // PRIVATE

    private static Boolean isResultCreatedForStep(String jobExecutionId) {
        Boolean stepHasResult = false;
        for(JobStep__c jobStep : jobSteps(jobExecutionId)) {
            if(jobStep.Result__c != null || !jobStep.Results__r.isEmpty()) {
                stepHasResult = true;
                break;
            }
        }
        return stepHasResult;
    }

    private static List<JobStep__c> jobSteps(String jobExecutionId) {
        return [SELECT Id, Name, Result__c, 
                        (SELECT Id FROM Results__r)
                FROM JobStep__c 
                WHERE JobExecution__c != NULL AND JobExecution__c = :jobExecutionId
                WITH SECURITY_ENFORCED];
    }
}