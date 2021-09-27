@isTest
private with sharing class RunTestsInExtensionTest {
    private static String category = 'Mock Type';
    private static String tool = 'Mock Tool';

    @TestSetup
    private static void setupData() {
        insertData();
    }

    @isTest
    private static void execute() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();

            List<Test__c> mockTests = getMockTests();

            // Exercise
            List<Result__c> results = new RunTestsInExtension(mockTests).execute();

            // Verify
            System.assertEquals(
                results.size(),
                [SELECT COUNT() FROM Result__c],
                'Result output RunTestsInExtension from be the same size than database results'
            );
            assertMockResult(results[0]);
        }
    }

    @isTest
    private static void executeWithoutExtensionSet() {
        System.runAs(getTestUser()) {
            // Setup
            List<Test__c> mockTests = getMockTests();

            // Exercise
            Exception ex;
            try {
                new RunTestsInExtension(mockTests).execute();
            } catch (Exception e) {
                ex = e;
            }

            // Verify
            System.assertEquals(ex.getMessage(), Label.NoTestExtensionConfigured, 'Exception should be: ' + Label.NoTestExtensionConfigured);
        }
    }

    @isTest
    private static void executeAsAutomation() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();
            Id deploymentJobId = getMockDeploymentJob().Id;

            // Exercise
            new RunTestsInExtension(new List<Test__c>{ getMockTest() }).executeAsAutomation(deploymentJobId);

            // Verify
            List<Result__c> results = [SELECT Id, Job_Type__c, Status__c, Progress_Status__c FROM Result__c];
            System.assertEquals(1, results.size(), '1 Mock Result should have been generated');
            assertMockResult(results[0]);

            Deployment_Job__c job = [SELECT Status__c FROM Deployment_Job__c WHERE Id = :deploymentJobId];
            System.assertEquals('Success', job.Status__c, 'Deployment Job Status should be success');
        }
    }

    @isTest
    private static void executeAsAutomationWithoutExtensionSet() {
        System.runAs(getTestUser()) {
            // Setup
            Id deploymentJobId = getMockDeploymentJob().Id;

            // Exercise
            Exception ex;
            try {
                new RunTestsInExtension(new List<Test__c>{ getMockTest() }).executeAsAutomation(deploymentJobId);
            } catch (Exception e) {
                ex = e;
            }

            // Verify
            System.assertEquals(0, [SELECT Count() FROM Result__c], 'No results shoud be generated');

            Deployment_Job__c job = [SELECT Status__c FROM Deployment_Job__c WHERE Id = :deploymentJobId];
            System.assertEquals('Failed', job.Status__c, 'Deployment Job Status should be failed');
        }
    }


    @SuppressWarnings('PMD.ApexUnitTestMethodShouldHaveIsTestAnnotation')
    private static void assertMockResult(Result__c mockResult) {
        System.assertEquals('Mock Type', mockResult.Job_Type__c, 'Result Job Type should be Mock Type');
        System.assertEquals('Success', mockResult.Progress_Status__c, 'Result Progress Status should be Success');
        System.assertEquals('Success', mockResult.Status__c, 'Result Status should be Success');
    }

    private static void insertData() {
        ITestDefaults userCreation = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers().executeDML();
        User adminUser = userCreation.getRunAsUsers().get('Admin')[0];

        System.runAs(adminUser) {
            TestUtilities.assignLicense(String.valueOf(adminUser.Username), true, true, true, true, true);
            createMockData();
        }
    }

    private static User getTestUser() {
        User testUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test@test.org' LIMIT 1].get(0);
        TestUtilities.assignLicense(String.valueOf(testUser.Username), true, true, true, true, true);

        return testUser;
    }

    private static void createMockData() {
        Test__c test1 = new Test__c(Name = 'Mock Test 1', Category__c = category, Tool__c = tool);
        Test__c test2 = new Test__c(Name = 'Mock Test 2', Category__c = category, Tool__c = tool);
        Test__c test3 = new Test__c(Name = 'Mock Test 3', Category__c = category, Tool__c = tool);
        Test__c test4 = new Test__c(Name = 'Mock Test 4', Category__c = category, Tool__c = tool);
        Test__c test5 = new Test__c(Name = 'Mock Test 5', Category__c = category, Tool__c = tool);

        insert new List<Test__c>{ test1, test2, test3, test4, test5 };

        Environment__c env1 = new Environment__c(Name = 'Mock Dev 1', Type__c = 'Sandbox');
        insert env1;

        Org__c org1 = new Org__c(
            Name = 'Mock Dev 1',
            Org_Type__c = 'Sandbox',
            Validated_Date__c = Datetime.now(),
            Environment__c = env1.Id,
            SFDC_Org_ID__c = 'SFDC_Dev1OrgId'
        );
        insert org1;

        Environment__c env2 = new Environment__c(Name = 'Mock Dev 2', Type__c = 'Sandbox');
        insert env2;

        Org__c org2 = new Org__c(
            Name = 'Mock Dev 1',
            Org_Type__c = 'Sandbox',
            Validated_Date__c = Datetime.now(),
            Environment__c = env2.Id,
            SFDC_Org_ID__c = 'SFDC_Dev2OrgId'
        );
        insert org2;

        Deployment__c deployment = new Deployment__c(Name = 'Mock Deployment', From_Org__c = org1.Id, Status__c = 'In progress');
        insert deployment;

        Destination_Org__c destinationOrg = new Destination_Org__c(Deployment__c = deployment.Id, Status__c = 'In progress', To_Org__c = org2.Id);
        insert destinationOrg;

        Step__c step = new Step__c(
            Name = 'Mock Step',
            dataJson__c = JSON.serialize(new AttachmentTriggerHelper.TestWrapper(test1.Id)),
            Deployment__c = deployment.Id,
            Order__c = 1,
            Status__c = 'In progress',
            Type__c = 'Test'
        );
        insert step;

        Deployment_Job__c deploymentJob = new Deployment_Job__c(
            Deployed__c = 1,
            Destination_Org__c = destinationOrg.Id,
            Status__c = 'In progress',
            Step__c = step.Id
        );
        insert deploymentJob;
    }

    private static List<Test__c> getMockTests() {
        return [SELECT Name, Tool__c FROM Test__c];
    }

    private static Test__c getMockTest() {
        return [SELECT Name, Tool__c FROM Test__c LIMIT 1];
    }

    private static Deployment_Job__c getMockDeploymentJob() {
        return [SELECT Id FROM Deployment_Job__c LIMIT 1];
    }

    private static void insertMockTestType() {
        TestType__mdt mockTestType = new TestType__mdt();
        mockTestType.ExecuteVia__c = 'TestExtensionMock';
        mockTestType.Namespace__c = '';
        mockTestType.Category__c = category;
        mockTestType.Tool__c = tool;

        TestTypesSelector.mock(new List<TestType__mdt>{ mockTestType });
    }
}