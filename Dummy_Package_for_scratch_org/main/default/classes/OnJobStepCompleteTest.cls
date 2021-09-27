@IsTest
private class OnJobStepCompleteTest {

    @IsTest
    private static void execute() {

        // Setup
        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;

        JobExecution__c execution = new JobExecution__c(Template__c = template.Id);
        insert execution;

        JobStep__c step1 = new JobStep__c(Name = 'step1', JobExecution__c = execution.Id, Type__c = 'Manual');
        JobStep__c step2 = new JobStep__c(Name = 'step2', JobExecution__c = execution.Id, Type__c = 'Manual');
        insert new List<SObject>{ step1, step2 };

        Result__c result1 = new Result__c(JobStep__c = step1.Id, Job_Type__c = 'Manual');
        insert result1;

        step1.Result__c = result1.Id;
        update step1;


        // Exercise
        Test.startTest();
        OnJobStepComplete.EventPayload payload = new OnJobStepComplete.EventPayload(true, null);

        Event__e stepCompleted = new Event__e();
        stepCompleted.Topic_Uri__c = '/events/copado/v1/step-result/' + result1.Id;
        stepCompleted.Payload__c = JSON.serialize(payload);
        Eventbus.publish(stepCompleted);
        Test.stopTest();


        // Verify
        System.assertEquals('Success', [SELECT Status__c FROM JobStep__c WHERE Id = :step1.Id].Status__c);
        System.assertEquals('In Progress', [SELECT Status__c FROM JobStep__c WHERE Id = :step2.Id].Status__c);
    }


    @IsTest
    private static void executeWithInvalidPayload() {

        // Setup
        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;

        JobExecution__c execution = new JobExecution__c(Template__c = template.Id);
        insert execution;

        JobStep__c step1 = new JobStep__c(Name = 'step1', JobExecution__c = execution.Id, Type__c = 'Manual');
        JobStep__c step2 = new JobStep__c(Name = 'step2', JobExecution__c = execution.Id, Type__c = 'Manual');
        insert new List<SObject>{ step1, step2 };

        Result__c result1 = new Result__c(JobStep__c = step1.Id, Job_Type__c = 'Manual');
        insert result1;

        step1.Result__c = result1.Id;
        update step1;


        // Exercise
        Test.startTest();
        OnJobStepComplete.EventPayload payload = new OnJobStepComplete.EventPayload(true, null);

        Event__e stepCompleted = new Event__e();
        stepCompleted.Topic_Uri__c = '/events/copado/v1/step-result/' + result1.Id;
        stepCompleted.Payload__c = '["invalidFormat"]';
        Eventbus.publish(stepCompleted);
        Test.stopTest();


        // Verify
        System.assertEquals('Failed', [SELECT Status__c FROM JobStep__c WHERE Id = :step1.Id].Status__c);
    }
}