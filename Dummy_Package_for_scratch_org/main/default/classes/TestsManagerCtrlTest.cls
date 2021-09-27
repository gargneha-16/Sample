@isTest
private with sharing class TestsManagerCtrlTest {
    private static String category = 'Mock Type';
    private static String tool = 'Mock Tool';

    @TestSetup
    private static void setupData() {
        insertData();
    }

    @isTest
    private static void executeForUserStory() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();
            User_Story__c mockUserStory = getMockUserStory();

            // Exercise
            TestsManagerCtrl.runTestsOf(mockUserStory.Id);

            // Verify
            List<Result__c> results = [SELECT Job_Type__c, Progress_Status__c, Status__c FROM Result__c];
            System.assertEquals(5, results.size(), '5 results should have been created for the test execution');
            assertMockResult(results[0]);
        }
    }

    @isTest
    private static void executeForFeature() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();
            Application_Feature__c mockFeature = getMockFeature();

            // Exercise
            TestsManagerCtrl.runTestsOf(mockFeature.Id);

            // Verify
            List<Result__c> results = [SELECT Job_Type__c, Progress_Status__c, Status__c FROM Result__c];
            System.assertEquals(10, results.size(), '10 results should have been created for the test execution');
            assertMockResult(results[0]);
        }
    }

    @isTest
    private static void executeForApplication() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();
            Application__c mockApplication = getMockApplication();

            // Exercise
            TestsManagerCtrl.runTestsOf(mockApplication.Id);

            // Verify
            List<Result__c> results = [SELECT Job_Type__c, Progress_Status__c, Status__c FROM Result__c];
            System.assertEquals(15, results.size(), '15 results should have been created for the test execution');
            assertMockResult(results[0]);
        }
    }

    @isTest
    private static void executeWithoutExtensionSet() {
        System.runAs(getTestUser()) {
            // Setup
            User_Story__c mockUserStory = getMockUserStory();

            // Exercise
            Exception ex;
            try {
                TestsManagerCtrl.runTestsOf(mockUserStory.Id);
            } catch (Exception e) {
                ex = e;
            }

            // Verify
            System.assertEquals(ex.getMessage(), Label.NoTestExtensionConfigured, 'Exception should be: ' + Label.NoTestExtensionConfigured);
        }
    }

    @isTest
    private static void getTestsForUserStory() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();
            User_Story__c mockUserStory = getMockUserStory();
            createRelatedResults(mockUserStory.Id);

            // Exercise
            List<TestsManagerCtrl.TestWrapper> tests = TestsManagerCtrl.getTests(mockUserStory.Id);

            // Verify
            System.assertEquals(5, tests.size(), 'there should be 5 tests for user story');
            assertGetTestMockResult(tests[0]);
        }
    }

    @isTest
    private static void getTestsForFeature() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();
            Application_Feature__c mockFeature = getMockFeature();
            createRelatedResults(mockFeature.Id);

            // Exercise
            List<TestsManagerCtrl.TestWrapper> tests = TestsManagerCtrl.getTests(mockFeature.Id);

            // Verify
            System.assertEquals(10, tests.size(), 'there should be 10 tests for Feature');
            assertGetTestMockResult(tests[0]);
        }
    }

    @isTest
    private static void getTestsForApplication() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();
            Application__c mockApplication = getMockApplication();
            createRelatedResults(mockApplication.Id);

            // Exercise
            List<TestsManagerCtrl.TestWrapper> tests = TestsManagerCtrl.getTests(mockApplication.Id);

            // Verify
            System.assertEquals(15, tests.size(), 'there should be 15 tests for application');
            assertGetTestMockResult(tests[0]);
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestMethodShouldHaveIsTestAnnotation')
    private static void assertMockResult(Result__c mockResult) {
        System.assertEquals('Mock Type', mockResult.Job_Type__c, 'Result Job Type should be Mock Type');
        System.assertEquals('Success', mockResult.Progress_Status__c, 'Result Progress Status should be Completed');
        System.assertEquals('Success', mockResult.Status__c, 'Result Status should be Completed');
    }

    @SuppressWarnings('PMD.ApexUnitTestMethodShouldHaveIsTestAnnotation')
    private static void assertGetTestMockResult(TestsManagerCtrl.TestWrapper test) {
        Result__c result = [SELECT Id, Name FROM Result__c WHERE Test__c = :test.Id LIMIT 1];

        System.assertEquals('Mock Test 1', test.name, 'Test Name should be Mock Test 1');
        System.assertEquals('Mock Type', test.testType, 'Test Type should be Mock Type');
        System.assertEquals('Mock Tool', test.testTool, 'Test Tool should be Mock Tool');
        System.assertEquals('Success', test.status, 'Result Status should be Success');
        System.assertEquals(result.Name, test.result, 'Result Status should be ' + result.Name);
        System.assertEquals('/' + result.id, test.resultUrl, 'Result Status should be ' + test.resultUrl);
        System.assertEquals(
            System.now().format('dd/MM/yyyy hh:mm a'),
            test.runDate,
            'Result Run date should be ' + System.now().format('dd/MM/yyyy hh:mm a')
        );
    }

    private static void insertData() {
        ITestDefaults userCreation = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers().executeDML();
        User adminUser = userCreation.getRunAsUsers().get('Admin')[0];

        System.runAs(adminUser) {
            createMockData();
        }
    }

    private static User getTestUser() {
        User testUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test@test.org' LIMIT 1].get(0);
        TestUtilities.assignLicense(String.valueOf(testUser.Username), true, true, true, true, true);

        return testUser;
    }

    private static void createMockData() {
        Application__c app = new Application__c();
        insert app;

        Application_Feature__c feature = new Application_Feature__c();
        feature.Application__c = app.Id;
        insert feature;

        User_Story__c us = new User_Story__c();
        us.US_Feature__c = feature.Id;
        insert us;

        insertTestRecords(us.Id);
        insertTestRecords(feature.Id);
        insertTestRecords(app.Id);
    }

    private static void insertTestRecords(String parentId) {
        List<Test__c> tests = new List<Test__c>();

        for (Integer i = 1; i <= 5; i++) {
            Test__c test = new Test__c();
            test.Name = 'Mock Test ' + i;
            test.Category__c = category;
            test.Tool__c = tool;
            linkTestTo(parentId, test);
            tests.add(test);
        }
        insert tests;
    }

    private static void linkTestTo(Id parentId, Test__c test) {
        SObjectType sobjectType = parentId.getSObjectType();

        if (sobjectType == User_Story__c.sObjectType) {
            test.User_Story__c = parentId;
        } else if (sobjectType == Application_Feature__c.sObjectType) {
            test.Feature__c = parentId;
        } else if (sobjectType == Application__c.sObjectType) {
            test.Application__c = parentId;
        }
    }

    private static void createRelatedResults(Id parentId) {
        List<Result__c> results = new List<Result__c>();
        List<Test__c> tests = new TestsSelector().byParent(parentId);

        for (Test__c test : tests) {
            results.add(testMethodUtilities.createResult(test.Id));
        }

        insert results;
    }

    private static User_Story__c getMockUserStory() {
        return [SELECT Id FROM User_Story__c LIMIT 1];
    }

    private static Application_Feature__c getMockFeature() {
        return [SELECT Id FROM Application_Feature__c LIMIT 1];
    }

    private static Application__c getMockApplication() {
        return [SELECT Id FROM Application__c LIMIT 1];
    }

    private static List<Test__c> getMockTests() {
        return [SELECT Name, Tool__c FROM Test__c];
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