@IsTest
private class PromotedUserStoriesDatatableCtrlTest {
    
    @TestSetup
    private static void setupData() {
        List<User> userList = TestDataFactory.createUsers();
        TestUtilities.enableLicenses(2, 2, 2, 2, 2);
        FeatureManagement.setPackageIntegerValue('CBM_Branches', 2);
        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name IN ('Copado_User', 'Copado_Functions', 'Copado_Job_Engine')];
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : permissionSets) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userList[0].Id, PermissionSetId = permissionSet.Id));
        }
        insert assignments;
    }

    static testMethod void fetchDataTest() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            String fieldSetName = namespace() + 'Promoted_User_Story_Datatable';
            PromotionTriggerHelper.createJobExecution = false;
            Promotion__c promotion = TestDataFactory.createPromotion(project.Id, null, environments[0].Id, null, null, 'Draft');
            insert promotion;

            promotion = [SELECT Id, Source_Environment__c, Source_Org_Credential__c, Destination_Environment__c, Destination_Org_Credential__c FROM Promotion__c WHERE Id = :promotion.Id];
            System.assertNotEquals(null, promotion.Source_Org_Credential__c);
            System.assertNotEquals(null, promotion.Destination_Environment__c);
            System.assertNotEquals(null, promotion.Destination_Org_Credential__c);

            Test.startTest();
            List<Promoted_User_Story__c> actualPromotedUserStories = PromotedUserStoriesDatatableController.fetchData(promotion.Id, fieldSetName);
            Test.stopTest();

            List<Promoted_User_Story__c> expectedPromotedUserStories = [SELECT Id FROM Promoted_User_Story__c WHERE Promotion__c = :promotion.Id AND User_Story__c = :userStory.Id];

            System.assertEquals(expectedPromotedUserStories.size(), actualPromotedUserStories.size());
        }
    }

    static testMethod void availableUserStoriesTest() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            String fieldSetName = namespace() + 'Promotion_Related_List_Datatable';
            PromotionTriggerHelper.createJobExecution = false;
            Promotion__c promotion = TestDataFactory.createPromotion(project.Id, null, environments[0].Id, null, null, 'Draft');
            insert promotion;

            promotion = [SELECT Id, Source_Environment__c, Source_Org_Credential__c, Destination_Environment__c, Destination_Org_Credential__c, Back_Promotion__c FROM Promotion__c WHERE Id = :promotion.Id];
            System.assertNotEquals(null, promotion.Source_Org_Credential__c);
            System.assertNotEquals(null, promotion.Destination_Environment__c);
            System.assertNotEquals(null, promotion.Destination_Org_Credential__c);

            Test.startTest();
            List<User_Story__c> actualUserStories = PromotedUserStoriesDatatableController.availableUserStories(promotion.Id, fieldSetName);
            Test.stopTest();

            List<User_Story__c> expectedUserStories = [SELECT Id FROM User_Story__c WHERE Promote_Change__c = TRUE AND Project__c = :project.Id AND Environment__c = :environments[0].Id];

            System.assertEquals(expectedUserStories.size(), actualUserStories.size());
        }
    }

    static testMethod void availableUserStoriesBackPromotionTest() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            String fieldSetName = namespace() + 'Promotion_Related_List_Datatable';
            PromotionTriggerHelper.createJobExecution = false;
            Promotion__c promotion = TestDataFactory.createPromotion(project.Id, null, null, null, environments[1].Id, 'Draft');
            promotion.Back_Promotion__c = true;
            insert promotion;

            promotion = [SELECT Id, Source_Environment__c, Source_Org_Credential__c, Destination_Environment__c, Destination_Org_Credential__c, Back_Promotion__c FROM Promotion__c WHERE Id = :promotion.Id];
            System.assertNotEquals(null, promotion.Source_Org_Credential__c);
            System.assertNotEquals(null, promotion.Destination_Environment__c);
            System.assertNotEquals(null, promotion.Destination_Org_Credential__c);

            Test.startTest();
            List<User_Story__c> actualUserStories = PromotedUserStoriesDatatableController.availableUserStories(promotion.Id, fieldSetName);
            Test.stopTest();

            List<User_Story__c> expectedUserStories = [SELECT Id FROM User_Story__c WHERE Promote_Change__c = TRUE AND Project__c = :project.Id AND Environment__c = :environments[2].Id];

            System.assertEquals(expectedUserStories.size(), actualUserStories.size());
        }
    }

    static testMethod void addSelectedUserStoriesToPromotionTest() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            String fieldSetName = namespace() + 'Promotion_Related_List_Datatable';
            PromotionTriggerHelper.createJobExecution = false;
            Promotion__c promotion = TestDataFactory.createPromotion(project.Id, null, environments[0].Id, null, null, 'Draft');
            insert promotion;

            promotion = [SELECT Id, Source_Environment__c, Source_Org_Credential__c, Destination_Environment__c, Destination_Org_Credential__c, Back_Promotion__c FROM Promotion__c WHERE Id = :promotion.Id];
            System.assertNotEquals(null, promotion.Source_Org_Credential__c);
            System.assertNotEquals(null, promotion.Destination_Environment__c);
            System.assertNotEquals(null, promotion.Destination_Org_Credential__c);

            Test.startTest();
            PromotedUserStoriesDatatableController.addSelectedUserStoriesToPromotion(promotion.Id, new List<Id>{ userStory.Id });
            Test.stopTest();

            List<Promoted_User_Story__c> actualPromotedUserStories = [SELECT Id FROM Promoted_User_Story__c WHERE Promotion__c = :promotion.Id AND User_Story__c = :userStory.Id];

            System.assertEquals(1, actualPromotedUserStories.size());
        }
    }

    static testMethod void removeSelectedPromotedUserStoriesTest() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            String fieldSetName = namespace() + 'Promotion_Related_List_Datatable';
            PromotionTriggerHelper.createJobExecution = false;
            Promotion__c promotion = TestDataFactory.createPromotion(project.Id, null, environments[0].Id, null, null, 'Draft');
            insert promotion;

            promotion = [SELECT Id, Source_Environment__c, Source_Org_Credential__c, Destination_Environment__c, Destination_Org_Credential__c, Back_Promotion__c FROM Promotion__c WHERE Id = :promotion.Id];
            System.assertNotEquals(null, promotion.Source_Org_Credential__c);
            System.assertNotEquals(null, promotion.Destination_Environment__c);
            System.assertNotEquals(null, promotion.Destination_Org_Credential__c);

            Test.startTest();
            PromotedUserStoriesDatatableController.addSelectedUserStoriesToPromotion(promotion.Id, new List<Id>{ userStory.Id });
            Map<Id, Promoted_User_Story__c> actualPromotedUserStoriesByIds = new Map<Id, Promoted_User_Story__c>([SELECT Id FROM Promoted_User_Story__c WHERE Promotion__c = :promotion.Id AND User_Story__c = :userStory.Id]);
            System.assertEquals(1, actualPromotedUserStoriesByIds.size());

            PromotedUserStoriesDatatableController.removeSelectedPromotedUserStories(new List<Id>( actualPromotedUserStoriesByIds.keyset() ));
            Test.stopTest();
            
            actualPromotedUserStoriesByIds = new Map<Id, Promoted_User_Story__c>([SELECT Id FROM Promoted_User_Story__c WHERE Promotion__c = :promotion.Id AND User_Story__c = :userStory.Id]);
            System.assertEquals(0, actualPromotedUserStoriesByIds.size());
        }
    }

    private static User_Story__c userStory;
    private static Deployment_Flow__c deploymentFlow;
    private static List<Environment__c> environments;
    private static JobTemplate__c deploymentJobTemplate;
    private static Project__c project;

    private static void data() {
        Personal_Settings__c ps = Personal_Settings__c.getInstance();
        if (String.isBlank(ps.API_Key__c)) {
            ps.API_Key__c = DeployAPI.encryptAPIKey('99999999999999999999');
            upsert ps;
        }

        //Environment creation
        environments = new List<Environment__c>();
        for (Integer i = 0; i < 3; i++) {
            Environment__c environment = TestDataFactory.createEnvironments('Environment ' + i, 'Production/Developer');
            environment.Platform__c = 'Other';
            environments.add(environment);
        }
        insert environments;

        // Git repository creation
        Git_Repository__c gitRepository = TestDataFactory.createGitRepository();
        insert gitRepository;

        // Deployment flow creation
        deploymentFlow = TestDataFactory.createDeploymentFlow('Deployment Flow', true, gitRepository.Id, false);
        deploymentFlow.Main_Branch__c = 'master';
        deploymentFlow.Platform__c = 'Other';
        insert deploymentFlow;

        // Deployment flow steps creation
        Deployment_Flow_Step__c deploymentFlowStep1 = TestDataFactory.createDeploymentFlowStep(
            environments[0].Id,
            environments[2].Id,
            deploymentFlow.Id,
            ''
        );
        deploymentFlowStep1.Branch__c = 'dev1';
        Deployment_Flow_Step__c deploymentFlowStep2 = TestDataFactory.createDeploymentFlowStep(
            environments[1].Id,
            environments[2].Id,
            deploymentFlow.Id,
            ''
        );
        deploymentFlowStep1.Branch__c = 'dev2';
        insert new List<Deployment_Flow_Step__c>{ deploymentFlowStep1, deploymentFlowStep2 };

        // Org Credential creation
        List<Org__c> credentials = [
            SELECT Id, Name, Environment__c, Platform__c, Oauth_Signature__c, Validated_Date__c, Disable_Validation__c, SFDC_Org_ID__c
            FROM Org__c
            WHERE Platform__c = 'Other'
        ];
        for (Org__c org : credentials) {
            org.Username__c = UserInfo.getUserName();
            org.SFDC_Org_ID__c = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();
            org.Oauth_Signature__c = org.Name;
            org.Validated_Date__c = System.now();
            org.Disable_Validation__c = true;
            break;
        }
        update credentials;

        // Project creation
        project = TestDataFactory.createProject('My project', deploymentFlow.Id, false);
        insert project;

        // User Story creation
        userStory = TestDataFactory.createUserStory('us-0000000', 'Approved', null, project.Id, null, credentials[0].Id);
        userStory.Promote_Change__c = true;
        insert userStory;
    }

    private static String namespace() {
        return Settings.ns;
    }

    private static String namespacePrefix() {
        return namespace().replace('__', '.');
    }
}