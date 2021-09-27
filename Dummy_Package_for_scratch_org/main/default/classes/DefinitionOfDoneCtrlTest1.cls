@isTest
private with sharing class DefinitionOfDoneCtrlTest1 {
   
    @isTest
    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    private static void validateGetTests(){
        System.runAs(getStandardUser()) {
            // Setup
            User_Story__c userStory = [Select Id from User_Story__c limit 1];
            // Exercise
            List<DefinitionOfDoneCtrl.Test> tests = DefinitionOfDoneCtrl.getTests(userStory.Id);
            // Verify
            assertTest(tests[0]);
        }
    }
    @SuppressWarnings('PMD.ApexUnitTestMethodShouldHaveIsTestAnnotation')
    private static void assertTest(DefinitionOfDoneCtrl.Test test){
        System.assertEquals('test',test.name, 'expected test but found '+test.name);
        System.assertEquals('test category',test.type, 'expected test category but found '+test.type);
        System.assertEquals('User Story',test.level, 'expected test tool but found '+test.level);
        System.assertEquals(false,test.isSuccess, 'expected true but found '+test.isSuccess);
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
        setOrgTimeZone(standardUser);
        return standardUser;
    }

    private static void setOrgTimeZone(User user) {
        List<Organization> organizations = [SELECT TimeZoneSidKey FROM Organization LIMIT 1];
        if(!organizations.isEmpty()){
            user.TimeZoneSidKey = organizations.get(0).TimeZoneSidKey;
            update user;
        }
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