@isTest
private with sharing class DefinitionOfDoneCtrlTest {
   
    @isTest
    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    private static void validateGetTests(){
        System.runAs(getStandardUser()) {
            // Setup
            User_Story__c userStory = [Select Id from User_Story__c limit 1];

            // Exercise
            List<DefinitionOfDoneCtrl.TestWrapper> tests = DefinitionOfDoneCtrl.getTests(userStory.Id);

            // Verify
            assertTest(tests[0]);
        }
    }

    @isTest
    private static void validateDeleteTest(){
        System.runAs(getStandardUser()) {
            // Setup
            List<Test__c> tests = [Select Id from Test__c ];
            System.assertEquals(1, tests.size(), 'there should be 1 test record');

            // Exercise
            DefinitionOfDoneCtrl.deleteTest(tests[0].Id);

            // Verify
            tests= [Select Id from Test__c where Id =:tests[0].Id];
            System.assertEquals(0, tests.size(), 'test should be deleted');
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestMethodShouldHaveIsTestAnnotation')
    private static void assertTest(DefinitionOfDoneCtrl.TestWrapper test){
        System.assertEquals('test',test.name, 'expected test but found '+test.name);
        System.assertEquals('test category',test.type, 'expected test category but found '+test.type);
        System.assertEquals('User Story',test.level, 'expected test tool but found '+test.level);
        System.assertEquals(true,test.isSuccess, 'expected true but found '+test.isSuccess);
    }

    @TestSetup
    private static void makeData() {
        User standardUser = setupUser();
        System.runAs(standardUser) {
            User_Story__c userStory = CMTestMethodUtilities.createUserStory('Test');
            insert userStory;
            Test__c test = TestMethodUtilities.createTest(userStory.Id);
            insert test;
            Result__c result = TestMethodUtilities.createResult(test.Id);
            insert result;
            
        }
    }

    private static User setupUser() {
        ITestDefaults userCreation = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers().executeDML();
        User standardUser = userCreation.getRunAsUsers().get('Standard')[0];

        return standardUser;
    }
    
    private static User getStandardUser() {
        User standardUser = [
            SELECT Id
            FROM User
            WHERE ProfileId IN (SELECT Id FROM Profile WHERE Name = 'Standard User')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return standardUser;
    }
}