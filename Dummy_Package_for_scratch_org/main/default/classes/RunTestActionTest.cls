@isTest
private with sharing class RunTestActionTest {
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

            Test__c mockTest = getMockTest();

            RunTestAction.Request request = new RunTestAction.Request();
            request.testId = mockTest.Id;
            List<RunTestAction.Request> requests = new List<RunTestAction.Request>{ request };

            // Exercise
            RunTestAction.execute(requests);

            // Verify
            List<Result__c> results = [SELECT Job_Type__c, Progress_Status__c, Status__c FROM Result__c];
            System.assertEquals(1, results.size(), '1 results should have been created for the test execution');
            assertMockResult(results[0]);
        }
    }

    @isTest
    private static void executeWithoutExtensionSet() {
        System.runAs(getTestUser()) {
            // Setup
            Test__c mockTest = getMockTest();

            RunTestAction.Request request = new RunTestAction.Request();
            request.testId = mockTest.Id;

            List<RunTestAction.Request> requests = new List<RunTestAction.Request>{ request };

            // Exercise
            Exception ex;
            try {
                RunTestAction.execute(requests);
            } catch (Exception e) {
                ex = e;
            }

            // Verify
            System.assertEquals(ex.getMessage(), Label.NoTestExtensionConfigured, 'Exception should be: ' + Label.NoTestExtensionConfigured);
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
            createMockTest();
        }
    }

    private static User getTestUser() {
        User testUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test@test.org' LIMIT 1].get(0);
        TestUtilities.assignLicense(String.valueOf(testUser.Username), true, true, true, true, true);

        return testUser;
    }

    private static void createMockTest() {
        Test__c test = new Test__c(Name = 'Mock Test', Category__c = category, Tool__c = tool);

        insert test;
    }

    private static Test__c getMockTest() {
        return [SELECT Name FROM Test__c LIMIT 1];
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