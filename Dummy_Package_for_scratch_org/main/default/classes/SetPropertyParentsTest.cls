@IsTest
private class SetPropertyParentsTest {
    @TestSetup
    private static void makeData() {
        TestUtilities.setTestSettingsEE();
    }

    @IsTest
    private static void createUserProperty() {
        // Exercise

        Test.startTest();
        System_Property__c property = new System_Property__c(API_Name__c = 'USER-PROPERTY', User__c = UserInfo.getUserId());
        insert property;
        Test.stopTest();

        // Verify

        property = [SELECT User__c, ParentId__c FROM System_Property__c WHERE Id = :property.Id];
        System.assertEquals(UserInfo.getUserId(), property.User__c, 'The parent user does not match the current user.');
        System.assertEquals(property.User__c, property.ParentId__c, 'The value in User__c was not copied into the property\'s ParentId field.');
    }

    @IsTest
    private static void createGitProperty() {
        // Setup

        Git_Repository__c repository = new Git_Repository__c();
        insert repository;

        // Exercise

        Test.startTest();
        System_Property__c property = new System_Property__c(API_Name__c = 'USER-PROPERTY', ParentId__c = repository.Id);
        insert property;
        Test.stopTest();

        // Verify

        property = [SELECT ParentId__c FROM System_Property__c WHERE Id = :property.Id];
        System.assertEquals(
            repository.Id,
            property.ParentId__c,
            'The value in ParentId does not match the Git Repository Id for which it was created.'
        );
    }

    @IsTest
    private static void updatePropertyParent() {
        // Setup

        Git_Repository__c repository = new Git_Repository__c();
        insert repository;
        System_Property__c property = new System_Property__c(API_Name__c = 'USER-PROPERTY', ParentId__c = repository.Id);
        insert property;

        // Exercise

        Test.startTest();
        property.User__c = UserInfo.getUserId();
        update property;
        Test.stopTest();

        // Verify

        property = [SELECT User__c, ParentId__c FROM System_Property__c WHERE Id = :property.Id];
        System.assertEquals(UserInfo.getUserId(), property.User__c, 'The parent user does not match the current user.');
        System.assertEquals(property.User__c, property.ParentId__c, 'The ParentId field was not overriden by the new parent that was set (User__c).');
    }
}