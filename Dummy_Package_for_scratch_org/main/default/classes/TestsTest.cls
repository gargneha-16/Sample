@isTest
private with sharing class TestsTest {
    @TestSetup
    private static void setupData() {
        insertData();
    }

    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @isTest
    private static void createTestWithCompleteHierarchy() {
        System.runAs(getTestUser()) {
            // Setup
            User_Story__c userStory = getUserStoryWithParent();

            // Exercise
            Test__c mockTest = new Test__c(Name = 'Mock Test', User_Story__c = userStory.Id);
            insert mockTest;

            // Verify
            mockTest = [SELECT User_Story__c, Feature__c, Application__c FROM Test__c LIMIT 1];
            assertUserStoryHierarchyIn(mockTest, userStory);
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @isTest
    private static void updateTestWithCompleteHierarchy() {
        System.runAs(getTestUser()) {
            // Setup
            Test__c mockTest = new Test__c(Name = 'Mock Test');
            insert mockTest;

            User_Story__c userStory = getUserStoryWithParent();

            // Exercise
            mockTest.User_Story__c = userStory.Id;
            update mockTest;

            // Verify
            mockTest = [SELECT User_Story__c, Feature__c, Application__c FROM Test__c LIMIT 1];
            assertUserStoryHierarchyIn(mockTest, userStory);
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @isTest
    private static void createTestWithMissingHierarchy() {
        System.runAs(getTestUser()) {
            // Setup
            Test__c mockTest = new Test__c(Name = 'Mock Test');
            insert mockTest;

            User_Story__c isolatedUserStory = getUserStoryWithoutParent();

            // Exercise
            mockTest.User_Story__c = isolatedUserStory.Id;
            update mockTest;

            // Verify
            mockTest = [SELECT User_Story__c, Feature__c, Application__c FROM Test__c LIMIT 1];
            assertUserStoryHierarchyIn(mockTest, isolatedUserStory);
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @isTest
    private static void updateTestWithMissingHierarchy() {
        System.runAs(getTestUser()) {
            // Setup
            Test__c mockTest = new Test__c(Name = 'Mock Test', User_Story__c = getUserStoryWithParent().Id);
            insert mockTest;

            User_Story__c isolatedUserStory = getUserStoryWithoutParent();

            // Exercise
            mockTest.User_Story__c = isolatedUserStory.Id;
            update mockTest;

            // Verify
            mockTest = [SELECT User_Story__c, Feature__c, Application__c FROM Test__c LIMIT 1];
            assertUserStoryHierarchyIn(mockTest, isolatedUserStory);
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @isTest
    private static void createTestWithFeatureHierarchy() {
        System.runAs(getTestUser()) {
            // Setup
            Application_Feature__c feature = getFeatureWithParent();

            // Exercise
            Test__c mockTest = new Test__c(Name = 'Mock Test', Feature__c = feature.Id);
            insert mockTest;

            // Verify
            mockTest = [SELECT User_Story__c, Feature__c, Application__c FROM Test__c LIMIT 1];
            assertFeatureHierarchyIn(mockTest, feature);
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @isTest
    private static void updateTestToDifferentFeatureHierarchy() {
        System.runAs(getTestUser()) {
            // Setup
            Test__c mockTest = new Test__c(Name = 'Mock Test', User_Story__c = getUserStoryWithParent().Id);
            insert mockTest;

            Application__c newApplication = new Application__c();
            insert newApplication;

            Application_Feature__c newFeature = new Application_Feature__c(Application__c = newApplication.Id);
            insert newFeature;

            // Exercise
            mockTest.Feature__c = newFeature.Id;
            update mockTest;

            // Verify
            mockTest = [SELECT User_Story__c, Feature__c, Application__c FROM Test__c LIMIT 1];
            assertFeatureHierarchyIn(mockTest, newFeature);
        }
    }

    @SuppressWarnings('PMD.ApexUnitTestMethodShouldHaveIsTestAnnotation')
    private static void assertUserStoryHierarchyIn(Test__c test, User_Story__c userStory) {
        System.assertEquals(userStory.Id, test.User_Story__c, 'User Story should be correctly assigned to the test');
        System.assertEquals(userStory.US_Feature__c, test.Feature__c, 'Feature in test should follow the user story hierarchy');
        System.assertEquals(
            userStory.US_Feature__r.Application__c,
            test.Application__c,
            'Application in test should follow the user story hierarchy'
        );
    }

    @SuppressWarnings('PMD.ApexUnitTestMethodShouldHaveIsTestAnnotation')
    private static void assertFeatureHierarchyIn(Test__c test, Application_Feature__c feature) {
        System.assertEquals(null, test.User_Story__c, 'User Story not be populated');
        System.assertEquals(feature.Id, test.Feature__c, 'Feature in test should follow the feature hierarchy');
        System.assertEquals(feature.Application__c, test.Application__c, 'Application in test should follow the feature hierarchy');
    }

    private static User_Story__c getUserStoryWithParent() {
        return [SELECT US_Feature__c, US_Feature__r.Application__c FROM User_Story__c WHERE US_Feature__c != NULL LIMIT 1];
    }

    private static User_Story__c getUserStoryWithoutParent() {
        return [SELECT US_Feature__c, US_Feature__r.Application__c FROM User_Story__c WHERE US_Feature__c = NULL LIMIT 1];
    }

    private static Application_Feature__c getFeatureWithParent() {
        return [SELECT Application__c FROM Application_Feature__c WHERE Application__c != NULL LIMIT 1];
    }

    private static void insertData() {
        User adminUser = setupUser();
        System.runAs(adminUser) {
            Application__c application = new Application__c();
            insert application;

            Application_Feature__c feature = new Application_Feature__c(Application__c = application.Id);
            insert feature;

            User_Story__c userStoryWithParents = new User_Story__c(US_Feature__c = feature.Id);
            insert userStoryWithParents;

            User_Story__c userStoryWithoutParents = new User_Story__c();
            insert userStoryWithoutParents;
        }
    }

    private static User setupUser() {
        ITestDefaults userCreation = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers().executeDML();
        User adminUser = userCreation.getRunAsUsers().get('Admin')[0];

        return adminUser;
    }

    private static User getTestUser() {
        return [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test@test.org' LIMIT 1].get(0);
    }
}