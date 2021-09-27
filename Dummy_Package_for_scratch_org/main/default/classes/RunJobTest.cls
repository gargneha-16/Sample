@IsTest
private class RunJobTest {
    @TestSetup
    private static void setupData() {
        List<User> users = TestDataFactory.createUsers();
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name = 'Copado_User' OR Name = 'Copado_Job_Engine']) {
            assignments.add(new PermissionSetAssignment(AssigneeId = users[0].Id, PermissionSetId = ps.Id));
        }
        insert assignments;
    }

    @IsTest
    private static void executeWithInvalidExecutionId() {
        // Setup
        Exception expectedException = null;
        RunJob.Request request = new RunJob.Request();

        // Exercise
        try {
            System.runAs(user()) {
                RunJob.execute(new List<RunJob.Request>{ request });
            }
        } catch (Exception ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
        System.assertEquals(Label.InvalidExecutionId, expectedException.getMessage());
    }

    @IsTest
    private static void shouldNotStartNextStepIfJobIsAlreadyInProgress() {
        // Setup
        Helper helper = new Helper().createExecution('In Progress').addStep('step1', 'Manual', 1, '');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;

        // Exercise
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
        }

        // Verify
        System.assertEquals(0, [SELECT COUNT() FROM Result__c]);
    }

    @IsTest
    private static void shouldResetResultOnExistingStepsOnRerun() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Failed')
            .addStep('step1', 'Manual', 1, '')
            .addStep('step2', 'Manual', 2, '')
            .addResultFor('step1', 'Manual', 'Success')
            .addResultFor('step2', 'Manual', 'Failed');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        System.assertEquals(3, [SELECT COUNT() FROM Result__c]);
        System.assertEquals('In Progress', [SELECT Status__c FROM JobExecution__c].Status__c);
        System.assertEquals(null, [SELECT Result__c FROM JobStep__c WHERE Name = 'step2'].Result__c);
        System.assertNotEquals(null, [SELECT Result__c FROM JobStep__c WHERE Name = 'step1'].Result__c);
    }

    @IsTest
    private static void shouldFailExecutionForInvalidFlow() {
        // Setup
        Helper helper = new Helper().createExecution('Not Started').addStep('step1', 'Flow', 2, '{"flowName" : "Invalid Flow"}');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
        }
        Test.stopTest();

        // Verify
        JobStep__c step1 = [SELECT Status__c, JobExecution__r.Status__c FROM JobStep__c WHERE Name = :'step1'];

        System.assertEquals(1, [SELECT COUNT() FROM Result__c]);

        System.assertEquals('Failed', step1.Status__c);
        System.assertEquals('Error', step1.JobExecution__r.Status__c);
    }

    @IsTest
    private static void shouldFailExecutionForInvalidFunctionName() {
        // Setup
        Helper helper = new Helper().createExecution('Not Started').addStep('step1', 'Function', 2, '{"functionName" : "Invalid Function"}');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;

        Org__c org = new Org__c();
        org.Validated_Date__c = System.today();
        org.SFDC_Org_ID__c = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();
        org.Username__c = UserInfo.getUserName();
        org.Oauth_Signature__c = 'Valid';
        insert org;

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
            Test.getEventBus().deliver();
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        String errorMessage = Label.Function_not_Found + ': Invalid Function';
        List<Result__c> results = [SELECT Error_Message__c FROM Result__c];

        System.assertEquals(1, results.size());
        System.assertEquals('Error', [SELECT Status__c FROM JobExecution__c].Status__c);
        System.assert(results[0].Error_Message__c.contains(errorMessage));
    }

    @IsTest
    private static void shouldCompleteIfAllStepsSucceed() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Not Started')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;
        request.allSteps = true;

        Flow.mockResponse = flowCompletionEvent(true, '', 'Success data 1');
        Function.mockResponse = functionCompletionEvent(true, '', 'Success data 2');

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
            Test.getEventBus().deliver();
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        JobStep__c step1 = [SELECT Status__c, Result__r.Result_Data__c FROM JobStep__c WHERE Name = 'step1'];
        JobStep__c step2 = [SELECT Status__c, Result__r.Result_Data__c FROM JobStep__c WHERE Name = 'step2'];

        System.assertEquals(2, [SELECT COUNT() FROM Result__c]);
        System.assertEquals('Successful', [SELECT Status__c FROM JobExecution__c].Status__c);

        System.assertEquals('Success', step1.Status__c);
        System.assertEquals('Success', step2.Status__c);

        System.assertEquals('Success data 1', step1.Result__r.Result_Data__c);
        System.assertEquals('Success data 2', step2.Result__r.Result_Data__c);
    }

    @IsTest
    private static void shouldFailIfAnyStepFails() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Not Started')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;
        request.allSteps = true;

        Flow.mockResponse = flowCompletionEvent(true, '', 'Success data');
        Function.mockResponse = functionCompletionEvent(false, 'Custom error', '');

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
            Test.getEventBus().deliver();
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        JobStep__c step1 = [SELECT Status__c, Result__r.Result_Data__c FROM JobStep__c WHERE Name = 'step1'];
        JobStep__c step2 = [SELECT Status__c, Result__r.Error_Message__c FROM JobStep__c WHERE Name = 'step2'];

        System.assertEquals(2, [SELECT COUNT() FROM Result__c]);
        System.assertEquals('Error', [SELECT Status__c FROM JobExecution__c].Status__c);

        System.assertEquals('Success', step1.Status__c);
        System.assertEquals('Failed', step2.Status__c);

        System.assertEquals('Success data', step1.Result__r.Result_Data__c);
        System.assertEquals('Custom error', step2.Result__r.Error_Message__c);
    }

    @IsTest
    private static void shouldReRunFailedStepsIfAnyStepFails() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Failed')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}')
            .addResultFor('step1', 'MockedFlow', 'Success')
            .addResultFor('step2', 'MockedFunction', 'Failed');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;
        request.allSteps = false;

        Org__c org = new Org__c();
        org.Oauth_Signature__c = 'Valid';
        org.Validated_Date__c = System.today();
        org.Username__c = UserInfo.getUserName();
        org.SFDC_Org_ID__c = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();
        insert org;

        Flow.mockResponse = flowCompletionEvent(true, '', 'Success data');
        Function.mockResponse = functionCompletionEvent(true, '', 'Sample Data');

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
            Test.getEventBus().deliver();
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        JobStep__c step2 = [SELECT Result__r.Result_Data__c, Status__c, JobExecution__r.Status__c FROM JobStep__c WHERE Name = 'step2'];

        System.assertEquals(3, [SELECT COUNT() FROM Result__c]);

        System.assertEquals('Success', step2.Status__c);
        System.assertEquals('Sample Data', step2.Result__r.Result_Data__c);
        System.assertEquals('Successful', step2.JobExecution__r.Status__c);
    }

    @IsTest
    private static void shouldReRunAllStepsIfAnyStepFails() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Failed')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}')
            .addResultFor('step1', 'MockedFlow', 'Success')
            .addResultFor('step2', 'MockedFunction', 'Failed');

        Flow.mockResponse = flowCompletionEvent(true, '', 'Success data');
        Function.mockResponse = functionCompletionEvent(true, '', 'Sample Data');

        RunJob.Request request = new RunJob.Request();
        request.jobId = helper.execution.Id;
        request.allSteps = true;

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJob.execute(new List<RunJob.Request>{ request });
            Test.getEventBus().deliver();
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        JobStep__c step2 = [SELECT Result__r.Result_Data__c, Status__c, JobExecution__r.Status__c FROM JobStep__c WHERE Name = 'step2'];

        System.assertEquals(4, [SELECT COUNT() FROM Result__c]);

        System.assertEquals('Success', step2.Status__c);
        System.assertEquals('Sample Data', step2.Result__r.Result_Data__c);
        System.assertEquals('Successful', step2.JobExecution__r.Status__c);
    }

    @IsTest
    private static void executeOutstanding() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Failed')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}')
            .addResultFor('step1', 'MockedFlow', 'Success')
            .addResultFor('step2', 'MockedFunction', 'Failed');

        insert credential();

        Flow.mockResponse = flowCompletionEvent(true, '', 'Success data');
        Function.mockResponse = functionCompletionEvent(true, '', 'Sample Data');

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJobController.execute(helper.execution.Id, false);
            Test.getEventBus().deliver();
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        JobStep__c step2 = [SELECT Result__r.Result_Data__c, Status__c, JobExecution__r.Status__c FROM JobStep__c WHERE Name = 'step2'];

        System.assertEquals(3, [SELECT COUNT() FROM Result__c]);

        System.assertEquals('Success', step2.Status__c);
        System.assertEquals('Sample Data', step2.Result__r.Result_Data__c);
        System.assertEquals('Successful', step2.JobExecution__r.Status__c);
    }

    @IsTest
    private static void restartExecution() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Failed')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}')
            .addResultFor('step1', 'MockedFlow', 'Success')
            .addResultFor('step2', 'MockedFunction', 'Failed');

        Flow.mockResponse = flowCompletionEvent(true, '', 'Success data');
        Function.mockResponse = functionCompletionEvent(true, '', 'Sample Data');

        // Exercise
        Test.startTest();
        System.runAs(user()) {
            RunJobController.execute(helper.execution.Id, true);
            Test.getEventBus().deliver();
        }
        Test.stopTest();
        Test.getEventBus().deliver();

        // Verify
        JobStep__c step2 = [SELECT Result__r.Result_Data__c, Status__c, JobExecution__r.Status__c FROM JobStep__c WHERE Name = 'step2'];

        System.assertEquals(4, [SELECT COUNT() FROM Result__c]);

        System.assertEquals('Success', step2.Status__c);
        System.assertEquals('Sample Data', step2.Result__r.Result_Data__c);
        System.assertEquals('Successful', step2.JobExecution__r.Status__c);
    }

    @IsTest
    private static void getNextStepOutstanding() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Failed')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}')
            .addResultFor('step1', 'MockedFlow', 'Success')
            .addResultFor('step2', 'MockedFunction', 'Failed');

        // Exercise
        JobStep__c nextStep;
        Test.startTest();
        System.runAs(user()) {
            nextStep = RunJobController.getNextStep(helper.execution.Id, false);
        }
        Test.stopTest();

        //Verify
        System.assertEquals('step2', nextStep.Name);
    }

    @IsTest
    private static void getNextStepRestartExecution() {
        // Setup
        Helper helper = new Helper()
            .createExecution('Failed')
            .addStep('step1', 'Flow', 1, '{"flowName" : "MockedFlow"}')
            .addStep('step2', 'Function', 2, '{"functionName" : "MockedFunction"}')
            .addResultFor('step1', 'MockedFlow', 'Success')
            .addResultFor('step2', 'MockedFunction', 'Failed');

        // Exercise
        JobStep__c nextStep;
        Test.startTest();
        System.runAs(user()) {
            nextStep = RunJobController.getNextStep(helper.execution.Id, true);
        }
        Test.stopTest();

        //Verify
        System.assertEquals('step1', nextStep.Name);
    }

    // HELPER

    private static Org__c credential() {
        return new Org__c(
            Oauth_Signature__c = 'Valid',
            Validated_Date__c = System.today(),
            Username__c = UserInfo.getUserName(),
            SFDC_Org_ID__c = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId()
        );
    }

    private static User user() {
        return [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
    }

    private class Helper {
        private JobTemplate__c template;
        private Function__c function;
        private JobExecution__c execution;
        private List<JobStep__c> steps = new List<JobStep__c>();

        private Helper createExecution(String status) {
            function = new Function__c();
            function.API_Name__c = 'MockedFunction';
            insert function;

            template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
            insert template;
            execution = new JobExecution__c(Template__c = template.Id, Status__c = status);
            insert execution;

            return this;
        }

        @SuppressWarnings('PMD.ExcessiveParameterList')
        private Helper addStep(String name, String type, Integer order, String configJson) {
            JobStep__c step = new JobStep__c();
            step.Name = name;
            step.Type__c = type;
            step.Order__c = order;
            step.ConfigJson__c = configJson;
            step.JobExecution__c = execution.Id;
            insert step;

            steps.add(step);

            return this;
        }

        private Helper addResultFor(String stepName, String type, String status) {
            JobStep__c step = findByName(stepName);
            Result__c result = new Result__c(JobStep__c = step.Id, Job_Type__c = type, Status__c = status, Function__c = function.Id);
            insert result;

            step.Result__c = result.Id;
            update step;

            return this;
        }

        private JobStep__c findByName(String stepName) {
            JobStep__c result;

            for (JobStep__c step : steps) {
                if (step.Name == stepName) {
                    result = step;
                    break;
                }
            }

            return result;
        }
    }

    private static Event__e flowCompletionEvent(Boolean isSuccess, String errorMessage, String data) {
        Event__e result = new Event__e();
        result.Topic_Uri__c = OnJobStepComplete.STEP_ENDPOINT;
        result.Payload__c = Json.serialize(new OnJobStepComplete.EventPayload(isSuccess, errorMessage, data));

        return result;
    }

    private static MC_Result__e functionCompletionEvent(Boolean isSuccess, String errorMessage, String data) {
        MC_Result__e result = new MC_Result__e();
        result.IsFinished__c = true;
        result.Result_Data__c = data;
        result.IsSuccess__c = isSuccess;
        result.Error_Message__c = errorMessage;

        return result;
    }
}