@IsTest
private class SetJobTemplateApiNameTest {

    @IsTest
    private static void execute() {
        // Setup
        JobTemplate__c template = new JobTemplate__c();
        template.Name = 'Sample';
        template.Version__c = 1;


        // Exercise
        insert template;


        // Verify
        System.assertEquals('Sample_1', [SELECT ApiName__c FROM JobTemplate__c WHERE Id = :template.Id].ApiName__c);
    }
}