@IsTest
private class SetJobStepApiNameTest {

    @IsTest
    private static void executeWithParentTemplate() {
        // Setup
        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;


        // Exercise
        insert new JobStep__c(Name = 'step1', JobTemplate__c = template.Id, Type__c = 'Manual');


        // Verify
        System.assertEquals(template.Name + '_step1', [SELECT ApiName__c FROM JobStep__c LIMIT 1].ApiName__c);
    }


    @IsTest
    private static void executeWithParentExecution() {
        // Setup
        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;

        JobExecution__c execution = new JobExecution__c(Template__c = template.Id);
        insert execution;
        execution = [SELECT Id, Name FROM JobExecution__c WHERE Id = :execution.Id];


        // Exercise
        insert new JobStep__c(Name = 'step1', JobExecution__c = execution.Id, Type__c = 'Manual');


        // Verify
        System.assertEquals(execution.Name + '_step1', [SELECT ApiName__c FROM JobStep__c LIMIT 1].ApiName__c);
    }
}