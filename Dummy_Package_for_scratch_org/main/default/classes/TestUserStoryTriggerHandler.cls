@isTest
private class TestUserStoryTriggerHandler {
    private static final String STANDARD_USER_QUERY = 'SELECT Username FROM User WHERE Username = \'test_user@myorg.com\' LIMIT 1';
    @testSetup
    static void setupData() {
        TestUtilities.enableLicenses(2, 2, 2, 2, 2, 30);
        ITestDefaults userCreation = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers();
        userCreation.executeDML();
    }
    static testMethod void testBeforeInsert() {
        User currentUser = Database.query(STANDARD_USER_QUERY);
        TestUtilities.assignLicense(currentUser.Username, true, true, true, true, true);
        System.runAs(currentUser) {
            Project__c testProject = CMTestMethodUtilities.createProject('my project');
            insert testProject;

            Sprint__c testSprint = CMTestMethodUtilities.createSprint('my sprint');
            testSprint.Project__c = testProject.Id;
            insert testSprint;

            List<User_Story__c> userStories = new List<User_Story__c>();
            for (Integer i = 0; i < 20; i++) {
                User_Story__c testUserStory = CMTestMethodUtilities.createUserStory('test');
                testUserStory.Sprint__c = testSprint.Id;
                testUserStory.Project__c = null;
                testUserStory.Story_Points_Other__c = 3;
                userStories.add(testUserStory);
            }

            Test.startTest();
            insert userStories;
            Test.stopTest();

            for (User_Story__c u : [SELECT Id, Project__c FROM User_Story__c]) {
                system.assertEquals(testProject.Id, u.Project__c);
            }

            Sprint__c sprint = [SELECT Id, PlannedVelocity__c FROM Sprint__c WHERE Id = :testSprint.Id LIMIT 1];
            system.assertEquals(sprint.PlannedVelocity__c, 60);
        }
    }
    static testMethod void testBeforeInsertBulk() {
        User currentUser = Database.query(STANDARD_USER_QUERY);
        TestUtilities.assignLicense(currentUser.Username, true, true, true, true, true);
        System.runAs(currentUser) {
            Project__c testProject = CMTestMethodUtilities.createProject('my project');
            insert testProject;

            List<Sprint__c> sprints = new List<Sprint__c>();
            for (Integer i = 0; i < 155; i++) {
                Sprint__c testSprint = CMTestMethodUtilities.createSprint('my sprint');
                testSprint.Project__c = testProject.Id;
                sprints.add(testSprint);
            }
            insert sprints;

            List<User_Story__c> userStories = new List<User_Story__c>();
            for (Sprint__c eachSprint : sprints) {
                for (Integer i = 0; i < 20; i++) {
                    User_Story__c testUserStory = CMTestMethodUtilities.createUserStory('test');
                    testUserStory.Sprint__c = eachSprint.Id;
                    testUserStory.Project__c = null;
                    testUserStory.Story_Points_Other__c = 3;
                    userStories.add(testUserStory);
                }
            }

            Test.startTest();
            insert userStories;
            Test.stopTest();

            for (User_Story__c u : [SELECT Id, Project__c FROM User_Story__c]) {
                System.assertEquals(testProject.Id, u.Project__c, 'Project Should be assigned');
            }

            for (Sprint__c sprint : [SELECT Id, PlannedVelocity__c FROM Sprint__c]) {
                System.assertEquals(sprint.PlannedVelocity__c, 60, 'Planned Velocity not updated correctly');
            }
        }
    }

    static testMethod void testBeforeUpdate() {
        User currentUser = Database.query(STANDARD_USER_QUERY);
        TestUtilities.assignLicense(currentUser.Username, true, true, true, true, true);

        System.runAs(currentUser) {
            Project__c testProject = CMTestMethodUtilities.createProject('my project');
            insert testProject;

            Sprint__c testSprint = CMTestMethodUtilities.createSprint('my sprint');
            testSprint.Project__c = testProject.Id;
            insert testSprint;

            Sprint__c newSprint = CMTestMethodUtilities.createSprint('my new sprint');
            newSprint.Project__c = testProject.Id;
            insert newSprint;

            List<User_Story__c> userStories = new List<User_Story__c>();
            for (Integer i = 0; i < 20; i++) {
                User_Story__c testUserStory = CMTestMethodUtilities.createUserStory('test');
                testUserStory.Sprint__c = null;
                testUserStory.Project__c = null;
                userStories.add(testUserStory);
            }
            insert userStories;

            Integer counter = 0;
            for (User_Story__c u : userStories) {
                u.Sprint__c = testSprint.Id;
                u.Project__c = null;
                u.Story_Points_Other__c = 3;
                if (counter < 10) {
                    u.Status__c = 'Completed';
                    counter++;
                }
            }

            Test.startTest();
            update userStories;

            for (User_Story__c u : [SELECT Id, Project__c FROM User_Story__c]) {
                system.assertEquals(testProject.Id, u.Project__c);
            }

            Sprint__c sprint = [SELECT Id, PlannedVelocity__c, ActualVelocity__c FROM Sprint__c WHERE Id = :testSprint.Id LIMIT 1];
            system.assertEquals(sprint.PlannedVelocity__c, 60);
            system.assertEquals(sprint.ActualVelocity__c, 30);

            List<User_Story__c> userStoriesToUpdate = new List<User_Story__c>();
            for (User_Story__c u : userStories) {
                u.Sprint__c = newSprint.Id;
                userStoriesToUpdate.add(u);
            }

            update userStoriesToUpdate;
            Test.stopTest();
            Set<Id> sprintIds = new Set<Id>{ testSprint.Id, newSprint.Id };

            List<Sprint__c> sprintRecords = [SELECT Id, PlannedVelocity__c, ActualVelocity__c FROM Sprint__c WHERE Id IN :sprintIds ORDER BY Id ASC];
            system.assertEquals(sprintRecords[0].PlannedVelocity__c, 0);
            system.assertEquals(sprintRecords[0].ActualVelocity__c, 0);

            system.assertEquals(sprintRecords[1].PlannedVelocity__c, 60);
            system.assertEquals(sprintRecords[1].ActualVelocity__c, 30);
        }
    }
    static testMethod void testWithEnvironment() {
        User currentUser = Database.query(STANDARD_USER_QUERY);
        TestUtilities.assignLicense(currentUser.Username, true, true, true, true, true);

        System.runAs(currentUser) {
            Environment__c env1 = new Environment__c(Name = 'Dev Environment');
            env1.Minimum_Apex_Test_Coverage__c = 85;
            insert env1;

            Org__c testOrg1 = CMTestMethodUtilities.createOrg('MyOrg1', 'Production', 'SFDC_OrgId', null, null, system.now(), env1.Id);
            insert testOrg1;

            Project__c testProject = CMTestMethodUtilities.createProject('my project');
            insert testProject;

            Sprint__c testSprint = CMTestMethodUtilities.createSprint('my sprint');
            testSprint.Project__c = testProject.Id;
            insert testSprint;

            User_Story__c testUserStory = CMTestMethodUtilities.createUserStory('test');
            testUserStory.Sprint__c = testSprint.Id;
            testUserStory.Org_Credential__c = testOrg1.Id;
            insert testUserStory;
            testUserStory = [SELECT Id, Minimum_Apex_Code_Coverage__c FROM User_Story__c WHERE Id = :testUserStory.Id];
            System.assertEquals(85, testUserStory.Minimum_Apex_Code_Coverage__c);

            testUserStory.Minimum_Apex_Code_Coverage__c = 50;
            update testUserStory;
            testUserStory = [SELECT Id, Minimum_Apex_Code_Coverage__c FROM User_Story__c WHERE Id = :testUserStory.Id];
            System.assertEquals(85, testUserStory.Minimum_Apex_Code_Coverage__c);

            testUserStory.Minimum_Apex_Code_Coverage__c = 95;
            update testUserStory;
            testUserStory = [SELECT Id, Minimum_Apex_Code_Coverage__c FROM User_Story__c WHERE Id = :testUserStory.Id];
            System.assertEquals(95, testUserStory.Minimum_Apex_Code_Coverage__c);
        }
    }
    static testMethod void deployPromotedUserStory() {
        User currentUser = Database.query(STANDARD_USER_QUERY);
        TestUtilities.assignLicense(currentUser.Username, true, true, true, true, true);

        System.runAs(currentUser) {
            Test.startTest();
            Deployment_Flow__c flow = CMTestMethodUtilities.createCCMFlow('Standard flow', true);
            insert flow;

            Project__c testProject = CMTestMethodUtilities.createProject('test project');
            testProject.Deployment_Flow__c = flow.Id;
            insert testProject;

            Environment__c env1 = new Environment__c(Name = 'UAT Environment');
            Environment__c env2 = new Environment__c(Name = 'Production Environment');
            insert new List<Environment__c>{ env1, env2 };

            Org__c testOrg1 = CMTestMethodUtilities.createOrg('MyOrg1', 'Production', 'SFDC_OrgId', null, null, system.now(), env1.Id);
            Org__c testOrg2 = CMTestMethodUtilities.createOrg('MyOrg2', 'Production', 'SFDC_OrgId2', null, null, system.now(), env2.Id);
            insert new List<Org__c>{ testOrg1, testOrg2 };

            Deployment_Flow_Step__c dfs = CMTestMethodUtilities.createFlowStep(env1.Id, env2.Id, flow.Id);
            insert dfs;

            List<User_Story__c> userStories = new List<User_Story__c>();
            for (Integer i = 0; i < 20; i++) {
                User_Story__c testUserStory = CMTestMethodUtilities.createUserStory('test');
                testUserStory.Sprint__c = null;
                testUserStory.Project__c = testProject.Id;
                userStories.add(testUserStory);
            }
            insert userStories;

            Test.setMock(HttpCalloutMock.class, new testHttpCalloutMock('{}', null));
            for (User_Story__c usItem : userStories) {
                usItem.Promote_and_Deploy__c = true;
            }
            update userStories;

            List<Promotion__c> promoResult = [SELECT Id, Name FROM Promotion__c];
            system.assertEquals(1, promoResult.size());

            List<Promoted_User_Story__c> pus = [
                SELECT Id, Name, User_Story__r.Name
                FROM Promoted_User_Story__c
                WHERE Promotion__c = :promoResult[0].Id
            ];
            system.assertEquals(20, pus.size());
            system.assertEquals('Promoted User Story: ' + pus[0].User_Story__r.Name, pus[0].Name);
            Test.stopTest();
        }
    }

    @IsTest
    private static void testSetChildPromotedUserStoriesAsOutdated() {
        User currentUser = Database.query(STANDARD_USER_QUERY);
        TestUtilities.assignLicense(String.valueOf(currentUser.Username), true, true, true, true, true);

        System.runAs(currentUser) {
            ITestDefaults environmentDefaults = new CCDFullCycleTestDefaults.EnvironmentDefaults()
                .setFieldDefaults()
                .setFieldValue(Environment__c.SObjectType, Environment__c.Name, 'Production Environment')
                .setDataSize(Environment__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.EnvironmentDefaults.class)
                .setFieldValue(Environment__c.SObjectType, Environment__c.Name, 'Staging Environment')
                .setFieldValue(Environment__c.SObjectType, Environment__c.Type__c, 'Sandbox')
                .setDataSize(Environment__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.EnvironmentDefaults.class)
                .setFieldValue(Environment__c.SObjectType, Environment__c.Name, 'Dev1 Environment')
                .setFieldValue(Environment__c.SObjectType, Environment__c.Type__c, 'Sandbox')
                .setDataSize(Environment__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.EnvironmentDefaults.class)
                .setFieldValue(Environment__c.SObjectType, Environment__c.Name, 'Dev2 Environment')
                .setFieldValue(Environment__c.SObjectType, Environment__c.Type__c, 'Sandbox')
                .setDataSize(Environment__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.EnvironmentDefaults.class)
                .setFieldValue(Environment__c.SObjectType, Environment__c.Name, 'Dev3 Environment')
                .setFieldValue(Environment__c.SObjectType, Environment__c.Type__c, 'Sandbox')
                .setDataSize(Environment__c.SObjectType, 1)
                .generateDefaults()
                .executeDML();

            Environment__c productionEnvironment = new Environment__c();
            Environment__c stagingEnvironment = new Environment__c();
            Environment__c dev1Environment = new Environment__c();
            Environment__c dev2Environment = new Environment__c();
            Environment__c dev3Environment = new Environment__c();

            for (Environment__c env : (List<Environment__c>) environmentDefaults.getTestData(Environment__c.SObjectType)) {
                switch on env.Name {
                    when 'Production Environment 0' {
                        productionEnvironment = env;
                    }
                    when 'Staging Environment 0' {
                        stagingEnvironment = env;
                    }
                    when 'Dev1 Environment 0' {
                        dev1Environment = env;
                    }
                    when 'Dev2 Environment 0' {
                        dev2Environment = env;
                    }
                    when 'Dev3 Environment 0' {
                        dev3Environment = env;
                    }
                }
            }

            ITestDefaults orgCredentialDefaults = new CCDFullCycleTestDefaults.OrgCredentialDefaults()
                .setFieldDefaults()
                .setFieldValue(Org__c.SObjectType, Org__c.Name, 'prod')
                .setFieldValue(Org__c.SObjectType, Org__c.Environment__c, productionEnvironment.Id)
                .setDataSize(Org__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.OrgCredentialDefaults.class)
                .setFieldValue(Org__c.SObjectType, Org__c.Name, 'staging')
                .setFieldValue(Org__c.SObjectType, Org__c.Environment__c, stagingEnvironment.Id)
                .setDataSize(Org__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.OrgCredentialDefaults.class)
                .setFieldValue(Org__c.SObjectType, Org__c.Name, 'dev1')
                .setFieldValue(Org__c.SObjectType, Org__c.Environment__c, dev1Environment.Id)
                .setDataSize(Org__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.OrgCredentialDefaults.class)
                .setFieldValue(Org__c.SObjectType, Org__c.Name, 'dev2')
                .setFieldValue(Org__c.SObjectType, Org__c.Environment__c, dev2Environment.Id)
                .setDataSize(Org__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.OrgCredentialDefaults.class)
                .setFieldValue(Org__c.SObjectType, Org__c.Name, 'dev3')
                .setFieldValue(Org__c.SObjectType, Org__c.Environment__c, dev3Environment.Id)
                .setDataSize(Org__c.SObjectType, 1)
                .generateDefaults()
                .executeDML();

            Org__c productionOrg = new Org__c();
            Org__c stagingOrg = new Org__c();
            Org__c dev1Org = new Org__c();
            Org__c dev2Org = new Org__c();
            Org__c dev3Org = new Org__c();

            for (Org__c org : (List<Org__c>) orgCredentialDefaults.getTestData(Org__c.SObjectType)) {
                switch on org.Name {
                    when 'prod 0' {
                        productionOrg = org;
                    }
                    when 'staging 0' {
                        stagingOrg = org;
                    }
                    when 'dev1 0' {
                        dev1Org = org;
                    }
                    when 'dev2 0' {
                        dev2Org = org;
                    }
                    when 'dev3 0' {
                        dev3Org = org;
                    }
                }
            }

            ITestDefaults gitRepositoryDefaults = new CCDFullCycleTestDefaults.GitRepositoryDefaults()
                .setFieldDefaults()
                .setDataSize(Git_Repository__c.SObjectType, 1)
                .includeDefaults(CCDFullCycleTestDefaults.PipelineDefaults.class)
                .setDataSize(Deployment_Flow__c.SObjectType, 1)
                .setSObjectRelation(
                    Deployment_Flow__c.SObjectType,
                    Git_Repository__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Deployment_Flow__c.Git_Repository__c => 1 }
                )
                .includeDefaults(CCDFullCycleTestDefaults.ProjectDefaults.class)
                .setDataSize(Project__c.SObjectType, 1)
                .setSObjectRelation(
                    Project__c.SObjectType,
                    Deployment_Flow__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Project__c.Deployment_Flow__c => 1 }
                )
                .includeDefaults(CCDFullCycleTestDefaults.UserStoryDefaults.class)
                .setDataSize(User_Story__c.SObjectType, 1)
                .setFieldValue(User_Story__c.SObjectType, User_Story__c.Environment__c, stagingEnvironment.Id)
                .setFieldValue(User_Story__c.SObjectType, User_Story__c.Org_Credential__c, stagingOrg.Id)
                .setSObjectRelation(
                    User_Story__c.SObjectType,
                    Project__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ User_Story__c.Project__c => 1 }
                )
                .generateDefaults()
                .executeDML();

            Deployment_Flow__c pipelineSetting = (Deployment_Flow__c) gitRepositoryDefaults.getTestData(Deployment_Flow__c.SObjectType)[0];

            ITestDefaults pipelineConnectionDefaults = new CCDFullCycleTestDefaults.PipelineConnectionDefaults()
                .setFieldDefaults()
                .setDataSize(Deployment_Flow_Step__c.SObjectType, 1)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Source_Environment__c, dev1Environment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Destination_Environment__c, stagingEnvironment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Branch__c, 'dev1')
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Deployment_Flow__c, pipelineSetting.Id)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.PipelineConnectionDefaults.class)
                .setDataSize(Deployment_Flow_Step__c.SObjectType, 1)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Source_Environment__c, dev2Environment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Destination_Environment__c, stagingEnvironment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Branch__c, 'dev2')
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Deployment_Flow__c, pipelineSetting.Id)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.PipelineConnectionDefaults.class)
                .setDataSize(Deployment_Flow_Step__c.SObjectType, 1)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Source_Environment__c, dev3Environment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Destination_Environment__c, stagingEnvironment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Branch__c, 'dev3')
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Deployment_Flow__c, pipelineSetting.Id)
                .generateDefaults()
                .includeDefaults(CCDFullCycleTestDefaults.PipelineConnectionDefaults.class)
                .setDataSize(Deployment_Flow_Step__c.SObjectType, 1)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Source_Environment__c, stagingEnvironment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Destination_Environment__c, productionEnvironment.Id)
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Branch__c, 'int')
                .setFieldValue(Deployment_Flow_Step__c.SObjectType, Deployment_Flow_Step__c.Deployment_Flow__c, pipelineSetting.Id)
                .generateDefaults();

            pipelineConnectionDefaults.executeDML();

            Project__c project = (Project__c) gitRepositoryDefaults.getTestData(Project__c.SObjectType)[0];

            User_Story__c userStory = (User_Story__c) gitRepositoryDefaults.getTestData(User_Story__c.SObjectType)[0];

            Test.startTest();

            ITestDefaults promotion1Defaults = new CCDFullCycleTestDefaults.PromotionDefaults()
                .setFieldDefaults()
                .setFieldValue(Promotion__c.SObjectType, Promotion__c.Project__c, project.Id)
                .setFieldValue(Promotion__c.SObjectType, Promotion__c.Source_Org_Credential__c, dev1Org.Id)
                .setFieldValue(Promotion__c.SObjectType, Promotion__c.Source_Environment__c, dev1Environment.Id)
                .setDataSize(Promotion__c.SObjectType, 1)
                .includeDefaults(CCDFullCycleTestDefaults.PromotedUserStoryDefaults.class)
                .setDataSize(Promoted_User_Story__c.SObjectType, 1)
                .setFieldValue(Promoted_User_Story__c.SObjectType, Promoted_User_Story__c.User_Story__c, userStory.Id)
                .setSObjectRelation(
                    Promoted_User_Story__c.SObjectType,
                    Promotion__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Promoted_User_Story__c.Promotion__c => 1 }
                )
                .generateDefaults()
                .executeDML();

            Promoted_User_Story__c promotedUserStory = (Promoted_User_Story__c) promotion1Defaults.getTestData(Promoted_User_Story__c.SObjectType)[0];
            System.assertEquals(stagingEnvironment.Id, userStory.Environment__c, 'User story environment should be staging');
            System.assertEquals(
                'Active',
                [SELECT Status__c FROM Promoted_User_Story__c WHERE Id = :promotedUserStory.Id]
                .Status__c,
                'Promoted user story status should be Active'
            );

            userStory.Org_Credential__c = dev1Org.Id;
            userStory.Environment__c = dev1Environment.Id;
            update userStory;
            Test.stopTest();

            System.assertEquals(dev1Environment.Id, userStory.Environment__c, 'User story environment should be dev1');
            System.assertEquals(
                'Outdated',
                [SELECT Status__c FROM Promoted_User_Story__c WHERE Id = :promotedUserStory.Id]
                .Status__c,
                'Promoted user story status should be Outdated'
            );
        }
    }
    @isTest
    private static void updatedBundleChildStory() {
        User u = getRunAsUser();
        System.runAs(u) {
            TestUtilities.assignLicense(u.Username, true, true, true, true, true);

            // Setup
            setup();
            bundlingJob();

            // Exercise
            User_Story__c bundle = fetchStoriesByRecordType('Utility').get(0);
            bundle.Status__c = 'Rejected';
            update bundle;

            //Verify
            User_Story__c us = fetchStoriesByRecordType('User_Story').get(0);
            System.assertEquals('Rejected', us.Status__c);
        }
    }

    @isTest
    private static void undoBundlingOnCancel() {
        User u = getRunAsUser();
        System.runAs(u) {
            TestUtilities.assignLicense(u.Username, true, true, true, true, true);

            // Setup
            setup();
            bundlingJob();

            // Exercise
            User_Story__c bundle = fetchStoriesByRecordType('Utility').get(0);
            bundle.Status__c = 'Cancelled';
            bundle.Cancellation_Reason__c = 'Cancelled';
            update bundle;

            //Verify
            bundle = fetchStoriesByRecordType('Utility').get(0);
            System.assertEquals(true, bundle.Stop_Indexing_Metadata__c);

            User_Story__c s = fetchStoriesByRecordType('User_Story').get(0);
            System.assertEquals(false, s.Stop_Indexing_Metadata__c);

            Artifact_Version__c v = [
                SELECT Id, Status__c, (SELECT Id FROM Bundled_Stories__r)
                FROM Artifact_Version__c
                WHERE User_Story__c = :bundle.Id
                LIMIT 1
            ];
            System.assertEquals('Cancelled', v.Status__c);
            System.assert(v.Bundled_Stories__r.isEmpty());
        }
    }

    @isTest
    private static void validateBundleChildCancellation() {
        User u = getRunAsUser();
        System.runAs(u) {
            TestUtilities.assignLicense(u.Username, true, true, true, true, true);

            // Setup
            setup();
            bundlingJob();

            // Exercise
            try {
                User_Story__c s = fetchStoriesByRecordType('User_Story').get(0);
                s.Status__c = 'Cancelled';
                s.Cancellation_Reason__c = 'Cancelled';
                update s;
            } catch (Exception ex) {
                //Verify
                System.assert(ex.getMessage().contains(Label.USB_ERROR_CHILD_CANCELLATION));
            }
        }
    }

    @isTest
    private static void allowUpdateAfterBundleCancel() {
        User u = getRunAsUser();
        System.runAs(u) {
            TestUtilities.assignLicense(u.Username, true, true, true, true, true);

            // Setup
            setup();
            bundlingJob();
            User_Story__c s = fetchStoriesByRecordType('Utility').get(0);
            s.Status__c = 'Cancelled';
            s.Cancellation_Reason__c = 'Cancelled';
            update s;

            // Exercise
            s.Status__c = 'Approved';
            update s;

            //Verify
            User_Story__c bundle = fetchStoriesByRecordType('Utility').get(0);
            System.assertEquals('Approved', bundle.Status__c);
        }
    }

    // HELPER

    private static User getRunAsUser() {
        TestDataFactory.createUsers();
        User copadoUser = [SELECT Id, Username FROM User WHERE Email = 'test2@test2.com' LIMIT 1];

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Copado_User'];
        insert new PermissionSetAssignment(AssigneeId = copadoUser.Id, PermissionSetId = ps.Id);

        return copadoUser;
    }

    private static List<User_Story__c> fetchStoriesByRecordType(String developerName) {
        return [SELECT Id, Status__c, Stop_Indexing_Metadata__c FROM User_Story__c WHERE RecordType.DeveloperName = :developerName];
    }

    private static void setup() {
        Org__c orgCred = TestDataFactory.createOrgCredentials('myUsrName', null, 'Sandbox');
        orgCred.Default_Credential__c = true;
        orgCred.SFDC_Org_ID__c = '00D1i00000095cEEAQ_0050X000007h8hTQAQ_6';
        insert orgCred;

        update orgCred;

        Environment__c env = [SELECT Id FROM Environment__c LIMIT 1];

        Git_Repository__c repo = TestDataFactory.createGitRepository();
        insert repo;

        Git_Backup__c snapshot = TestDataFactory.createGitBackup('SnapShot1', orgCred.Id, repo.Id);
        insert snapshot;

        Deployment_Flow__c pipeline = TestDataFactory.createDeploymentFlow('Test Pipeline', true, repo.Id, false);
        insert pipeline;

        Project__c project = TestDataFactory.createProject('test project', pipeline.Id, false);
        insert project;

        List<User_Story__c> userStories = TestDataFactory.createUserStories(2, 'US', 'Approved', null, project.Id, env.Id, orgCred.Id, 'User_Story');
        insert userStories;
    }

    private static void bundlingJob() {
        List<Artifact__c> pkg = TestDataFactory.createPackages(1, 'pkg', 'User_Story_Bundle');
        insert pkg;

        List<Artifact_Version__c> version = TestDataFactory.createPackageVersions(1, 'pkgVersion', pkg.get(0).Id);
        insert version;

        List<User_Story__c> stories = [
            SELECT Id, Status__c, Project__c, Environment__c, Org_Credential__c
            FROM User_Story__c
            WHERE RecordType.DeveloperName = 'User_Story'
        ];
        List<Bundled_Story__c> bundledStories = TestDataFactory.createBundledStories(version.get(0).Id, stories);
        insert bundledStories;

        List<User_Story__c> bundleStory = TestDataFactory.createUserStories(
            1,
            'USB',
            'Approved',
            null,
            stories[0].Project__c,
            stories[0].Environment__c,
            stories[0].Org_Credential__c,
            'Utility'
        );
        bundleStory.get(0).Is_Bundle__c = true;
        insert bundleStory;

        version.get(0).User_Story__c = bundleStory.get(0).Id;
        update version;
    }
}