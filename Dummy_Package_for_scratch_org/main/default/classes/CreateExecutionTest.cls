@IsTest
private class CreateExecutionTest {

    @TestSetup
    private static void setupData() {
        List<User> users = TestDataFactory.createUsers();
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        for(PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name = 'Copado_User' OR Name = 'Copado_Job_Engine']) {
            assignments.add(new PermissionSetAssignment(AssigneeId = users[0].Id, PermissionSetId = ps.Id));
        }
        insert assignments;
    }


    @IsTest
    private static void executeWithInvalidTemplateName() {

        // Setup
        Exception expectedException = null;

        Git_Commit__c gitCommit = new Git_Commit__c();
        insert gitCommit;

        CreateExecution.request request = new CreateExecution.request();
        request.parentId = gitCommit.Id;
        request.templateName = 'Invalid Template';

        List<CreateExecution.request> requests = new List<CreateExecution.request> { request };

        // Exercise
        try {
            CreateExecution.execute(requests);
        }
        catch(Exception ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
        System.assertEquals(Label.InvalidTemplateId, expectedException.getMessage());
    }


    @IsTest
    private static void executeWithRunAfterInstantiationDisabled() {

        // Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];

        JobTemplate__c template = new JobTemplate__c();
        template.Name = 'Sample';
        template.Version__c = 1;
        template.VolumeOptions__c = '[{ "name": "volumeEnabled", "value": "true" }]';
        insert template;

        JobStep__c step1 = new JobStep__c(Name = 'step1', JobTemplate__c = template.Id, Type__c = 'Manual');
        JobStep__c step2 = new JobStep__c(Name = 'step2', JobTemplate__c = template.Id, Type__c = 'Manual');
        insert new List<SObject>{ step1, step2 };

        Git_Commit__c gitCommit = new Git_Commit__c();
        insert gitCommit;

        CreateExecution.request request = new CreateExecution.request();
        request.templateName = 'Sample_1';
        request.dataJson = '{"key1": "value1"}';
        request.parentId = gitCommit.Id;

        List<CreateExecution.request> requests = new List<CreateExecution.request> { request };


        // Exercise
        List<JobExecution__c> executions;
        System.runAs(copadoUser) {
            executions = CreateExecution.execute(requests);
        }

        // Verify
        System.assertEquals(1, executions.size());
        JobExecution__c execution = executions[0];
        List<Parameter> parameters = (List<Parameter>)JSON.deserialize(execution.VolumeOptions__c, List<Parameter>.class);

        System.assertEquals(2, parameters.size());

        System.assertEquals('true', parameters[0].value);
        System.assertEquals('volumeEnabled', parameters[0].name);

        System.assertEquals(execution.Id, parameters[1].value);
        System.assertEquals('transactionId', parameters[1].name);

        System.assertEquals('Not Started', execution.Status__c);
        System.assertEquals('{"key1": "value1"}', execution.DataJson__c);
        System.assertEquals(2, [SELECT count() FROM JobStep__c WHERE JobExecution__c = :execution.Id]);
    }


    @IsTest
    private static void executeWithPreAndPostSteps() {

        // Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        User_Story__c userStory = new User_Story__c();
        insert userStory;

        JobStep__c step1 = new JobStep__c(Name = 'step1', UserStory__c = userStory.Id, Type__c = 'Manual', Order__c = 5, ExecutionSequence__c = 'before');
        JobStep__c step2 = new JobStep__c(Name = 'step2', UserStory__c = userStory.Id, Type__c = 'Manual', Order__c = 30, ExecutionSequence__c = 'before');

        JobStep__c step5 = new JobStep__c(Name = 'step5', UserStory__c = userStory.Id, Type__c = 'Manual', Order__c = 1, ExecutionSequence__c = 'after');
        JobStep__c step6 = new JobStep__c(Name = 'step6', UserStory__c = userStory.Id, Type__c = 'Manual', Order__c = 2, ExecutionSequence__c = 'after');

        JobTemplate__c template = new JobTemplate__c();
        template.Name = 'Sample';
        template.Version__c = 1;
        insert template;

        JobStep__c step3 = new JobStep__c(Name = 'step3', JobTemplate__c = template.Id, Type__c = 'Manual', Order__c = 10);
        JobStep__c step4 = new JobStep__c(Name = 'step4', JobTemplate__c = template.Id, Type__c = 'Manual', Order__c = 20);
        insert new List<SObject>{ step1, step2, step3, step4, step5, step6 };

        Git_Commit__c gitCommit = new Git_Commit__c();
        insert gitCommit;

        CreateExecution.request request = new CreateExecution.request();
        request.parentId = gitCommit.Id;
        request.templateName = 'Sample_1';
        request.preSteps = new List<JobStep__c> { step1, step2 };
        request.postSteps = new List<JobStep__c> { step5, step6 };

        List<CreateExecution.request> requests = new List<CreateExecution.request> { request };


        // Exercise
        List<JobExecution__c> executions;
        System.runAs(copadoUser) {
            executions = CreateExecution.execute(requests);
        }

        // Verify
        System.assertEquals(1, executions.size());
        JobExecution__c execution = executions[0];
        List<JobStep__c> steps = [SELECT Name, Order__c FROM JobStep__c WHERE JobExecution__c = :execution.Id ORDER BY Order__c ASC];

        System.assertEquals(6, steps.size());

        System.assertEquals(1, steps[0].Order__c);
        System.assertEquals('step1', steps[0].Name);

        System.assertEquals(2, steps[1].Order__c);
        System.assertEquals('step2', steps[1].Name);

        System.assertEquals(3, steps[2].Order__c);
        System.assertEquals('step3', steps[2].Name);

        System.assertEquals(4, steps[3].Order__c);
        System.assertEquals('step4', steps[3].Name);

        System.assertEquals(5, steps[4].Order__c);
        System.assertEquals('step5', steps[4].Name);

        System.assertEquals(6, steps[5].Order__c);
        System.assertEquals('step6', steps[5].Name);
    }


    @IsTest
    private static void executeWithRunAfterInstantiationEnabled() {

        // Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;

        Git_Commit__c gitCommit = new Git_Commit__c();
        insert gitCommit;

        CreateExecution.request request = new CreateExecution.request();
        request.templateName = 'Sample_1';
        request.parentId = gitCommit.Id;
        request.runAfterInstantiation = true;

        List<CreateExecution.request> requests = new List<CreateExecution.request> { request };

        // Exercise
        Test.startTest();
        List<JobExecution__c> executions;
        System.runAs(copadoUser) {
            executions = CreateExecution.execute(requests);
        }
        Test.stopTest();


        // Verify
        System.assertEquals(1, executions.size());
        System.assertEquals(0, [SELECT count() FROM JobStep__c]);
        System.assertEquals('Successful', [Select Status__c FROM JobExecution__c WHERE Id = :executions[0].Id].Status__c);
    }
}