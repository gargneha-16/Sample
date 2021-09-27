public with sharing class FunctionStepExecutionCallback implements MCCallBack {
    private List<Deployment_Job__c> deploymentJobs { get; set; }
    private Set<String> statusValues = new Set<String>{ 'Success', 'Failed' };

    public void execute(Function__c function, Result__c result, String status) {
        System.debug('**f**function : ' + function);
        System.debug('**f**result : ' + result);
        System.debug('**f**status : ' + status);
        if (String.isNotBlank(status) && statusValues.contains(status)) {
            initializeVariables();
            getDeploymentJob(result);
            updateDeploymentJobToUpdateDeploymentStatus(result, status);
        }
    }

    private void initializeVariables() {
        deploymentJobs = new List<Deployment_Job__c>();
    }

    private void getDeploymentJob(Result__c result) {
        deploymentJobs = [SELECT Id, Status__c, Last_Result__c FROM Deployment_Job__c WHERE Id = :result.ParentId__c WITH SECURITY_ENFORCED LIMIT 1];
    }

    private void updateDeploymentJobToUpdateDeploymentStatus(Result__c result, String status) {
        for (Deployment_Job__c deploymentJobRecord : deploymentJobs) {
            deploymentJobRecord.Status__c = status;
            deploymentJobRecord.Last_Result__c = result.Id;
        }
        SObjectAccessDecision deploymentJobDecision = Security.stripInaccessible(AccessType.UPDATABLE, deploymentJobs);
        update deploymentJobDecision.getRecords();
    }
}