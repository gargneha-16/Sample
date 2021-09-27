@isTest
private with sharing class CreateExtensionTestCtrlTest {
    private static String category = 'Mock Type';
    private static String tool = 'Mock Tool';

    @TestSetup
    private static void makeData() {
        setupUser();
    }

    @isTest
    private static void getTestTypesInfo() {
        System.runAs(getTestUser()) {
            // Setup
            insertMockTestType();

            // Exercise
            CreateExtensionTestCtrl.TestTypesWrapper wrapper = CreateExtensionTestCtrl.getTestTypesInfo();

            // Verify
            assertCategories(wrapper);
            assertTools(wrapper);
        }
    }

    @isTest
    private static void getTestTypesInfoWithNoRecords() {
        System.runAs(getTestUser()) {
            // Exercise
            CreateExtensionTestCtrl.TestTypesWrapper wrapper = CreateExtensionTestCtrl.getTestTypesInfo();

            // Verify
            System.assertEquals(0, wrapper.categories.size());
            System.assertEquals(0, wrapper.tools.size());
        }
    }

    private static void assertCategories(CreateExtensionTestCtrl.TestTypesWrapper wrapper) {
        System.assertEquals(1, wrapper.categories.size());
        System.assertEquals(category, wrapper.categories[0].label);
        System.assertEquals(category, wrapper.categories[0].value);
    }

    private static void assertTools(CreateExtensionTestCtrl.TestTypesWrapper wrapper) {
        System.assertEquals(1, wrapper.tools.size());
        System.assertEquals(tool, wrapper.tools[0].label);
        System.assertEquals(tool, wrapper.tools[0].value);
    }

    private static User setupUser() {
        ITestDefaults userCreation = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers().executeDML();
        User standardUser = userCreation.getRunAsUsers().get('Standard')[0];

        return standardUser;
    }

    private static User getTestUser() {
        User testUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test@test.org' LIMIT 1].get(0);
        TestUtilities.assignLicense(String.valueOf(testUser.Username), true, true, true, true, true);

        return testUser;
    }

    private static void insertMockTestType() {
        TestType__mdt mockTestType = new TestType__mdt();
        mockTestType.ExecuteVia__c = 'MockClass';
        mockTestType.Namespace__c = 'MockNamespace';
        mockTestType.Category__c = category;
        mockTestType.Tool__c = tool;

        TestTypesSelector.mock(new List<TestType__mdt>{ mockTestType });
    }
}