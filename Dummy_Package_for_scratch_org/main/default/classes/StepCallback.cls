public with sharing class StepCallback implements MCCallBack {

    // PUBLIC

    public void execute(Function__c function, Result__c result, String status) {
        execute(result.JobStep__r.JobExecution__c, status);
    }


    public void execute(Id jobId, String status) {
        if(status == 'Success') {
            if(Test.isRunningTest()) {
                new RunJob(jobId).executeNextStep();
            } else {
                System.enqueueJob(new RunJob(jobId));
            }   
        }
        else if(status == 'Failed' || status == 'Error') {
            new RunJob(jobId).finish('Error');
        }
    }
}