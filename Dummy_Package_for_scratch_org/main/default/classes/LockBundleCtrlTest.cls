@IsTest
private class LockBundleCtrlTest {
    @TestSetup
    private static void setupData() {
        createData();
    }

    @IsTest
    private static void testLockBundle() {
        System.runAs(getUser()) {
            // Setup
            User_Story__c story = createBundleStory();
            Artifact_Version__c bundle = getPackageVersionByName('My_Bundle');

            // Exercise
            Test.startTest();
            LockBundleCtrl.lockBundle(story, bundle.Id);
            Test.stopTest();

            // Verify
            Set<Id> chidrenIds = new Set<Id>();
            User_Story__c resultStory = [
                SELECT Id, User_Story_Title__c, Project__c, Org_Credential__c, Environment__c, Is_Bundle__c, RecordType.Name
                FROM User_Story__c
                WHERE User_Story_Title__c LIKE '%My Parent Story%'
            ];

            Artifact_Version__c resultBundle = [
                SELECT Id, User_Story__c, Status__c, (SELECT User_Story__c FROM Bundled_Stories__r)
                FROM Artifact_Version__c
                WHERE Id = :bundle.Id
            ];
            System.assertEquals(4, resultBundle.Bundled_Stories__r.size(), 'Size of of bundles stories is not correct');
            for (Bundled_Story__c record : resultBundle.Bundled_Stories__r) {
                chidrenIds.add(record.User_Story__c);
            }
            Map<Id, Deployment_Task__c> deploymentTasks = new Map<Id, Deployment_Task__c>(new DeploymentTasksSelector().byStories(chidrenIds));
            Map<Id, Deployment_Task__c> resultDeploymentTasks = new Map<Id, Deployment_Task__c>(
                new DeploymentTasksSelector().byStories(new Set<Id>{ resultStory.Id })
            );

            List<Attachment> fromChildren = new AttachmentsSelector().byParentId(deploymentTasks.keySet());
            List<Attachment> fromResult = new AttachmentsSelector().byParentId(resultDeploymentTasks.keyset());

            List<User_Story__c> children = [SELECT Id, Stop_Indexing_Metadata__c, Exclude_From_CBM__c FROM User_Story__c WHERE Id = :chidrenIds];
            System.assertEquals(4, children.size(), 'Size of of child stories is not correct');
            for (User_Story__c item : children) {
                System.assertEquals(true, item.Stop_Indexing_Metadata__c, 'This field should be true');
                System.assertEquals(true, item.Exclude_From_CBM__c, 'This field should be true');
            }
            
            System.assertEquals(true, resultStory.Is_Bundle__c, 'Is bundle must be True');
            System.assertEquals('Utility', resultStory.RecordType.Name, 'Record type must be Utility');
            System.assertEquals(story.User_Story_Title__c, resultStory.User_Story_Title__c, 'Title is not correct');
            System.assertEquals(story.Project__c, resultStory.Project__c, 'Project is not correct');
            System.assertEquals(story.Org_Credential__c, resultStory.Org_Credential__c, 'Org Credential is not correct');
            System.assertEquals(story.Environment__c, resultStory.Environment__c, 'Environment is not correct');

            System.assertEquals(resultBundle.User_Story__c, resultStory.Id, 'User Story in Bundle is not correct');
            System.assertEquals('Locked', resultBundle.Status__c, 'Status must be Locked');

            System.assertEquals(deploymentTasks.size(), resultDeploymentTasks.size(), 'Lists no match');
            System.assertEquals(fromChildren.size(), fromResult.size(), 'Lists no match');
        }
    }

    @IsTest
    private static void testEnvironmentConsistency() {
        System.runAs(getUser()) {
            // Setup
            String result;

            User_Story__c story = createBundleStory();
            story.Environment__c = null;

            // Exercise
            try {
                LockBundleCtrl.lockBundle(story, getPackageVersionByName('My_Bundle').Id);
            } catch (Exception ex) {
                result = ex.getMessage();
            }

            // Verify
            System.assertEquals('Environments in the selection does not match', result, 'Messages does not match');
        }
    }

    @IsTest
    private static void testPipelineConsistency() {
        System.runAs(getUser()) {
            // Setup
            String result;

            Project__c project = new Project__c(Name = 'MyProject 2');
            insert project;

            User_Story__c story = createBundleStory();
            story.Project__c = project.Id;

            // Exercise
            try {
                LockBundleCtrl.lockBundle(story, getPackageVersionByName('My_Bundle').Id);
            } catch (Exception ex) {
                System.debug('** getStackTraceString: ' + ex.getStackTraceString());
                result = ex.getMessage();
            }

            // Verify
            System.assertEquals('Pipelines in the selection does not match', result, 'Messages does not match');
        }
    }

    @IsTest
    private static void testGetFieldsFieldset() {
        System.runAs(getUser()) {
            // Exercise
            List<String> result = LockBundleCtrl.getFieldsFromFieldSet(SObjectType.User_Story__c.getName(), Settings.ns + 'Bundle');

            // Verify

            List<FieldSetMember> fields = Schema.SObjectType.User_Story__c.fieldSets.getMap().get(Settings.ns + 'Bundle').getFields();

            System.assertEquals(fields.size(), result.size());
        }
    }

    @IsTest
    private static void getLockedChildStories() {
        System.runAs(getUser()) {
            // Setup
            Artifact_Version__c lockedVersion = getPackageVersionByName('My_Bundle');
            lockedVersion.Name = 'Locked_Bundle';
            lockedVersion.Status__c = 'Locked';
            update lockedVersion;

            // Exercise
            createTestBundle();
            Artifact_Version__c newVersion = getPackageVersionByName('My_Bundle');
            List<String> lockedStories = LockBundleCtrl.getLockedChildStories(newVersion.Id);

            // Verify
            System.assertEquals(4, lockedStories.size());
        }
    }

    @IsTest
    private static void getPrefilledStory() {
        System.runAs(getUser()) {
            // Setup
            Artifact_Version__c version = getPackageVersionByName('My_Bundle');
            User_Story__c us = fetchStoriesByRecordType('User_Story').get(0);

            // Exercise
            User_Story__c result = LockBundleCtrl.createPrefilledStory(version.Id);

            // Verify
            System.assertEquals(version.Name, result.User_Story_Title__c);
            System.assertEquals(us.Project__c, result.Project__c);
            System.assertEquals(us.Release__c, result.Release__c);
            System.assertEquals(us.Org_Credential__c, result.Org_Credential__c);
            System.assertEquals(us.Environment__c, result.Environment__c);
        }
    }

    @IsTest
    private static void getPrefilledStoryWithDefaultCredential() {
        System.runAs(getUser()) {
            // Setup
            User_Story__c us = fetchStoriesByRecordType('User_Story').get(0);
            Org__c o = TestDataFactory.createOrgCredentials('dev2@testOrg.com', us.Environment__c, 'Production/Developer');
            o.Default_Credential__c = true;
            insert o;

            us.Org_Credential__c = o.Id;
            update us;

            // Exercise
            User_Story__c result = LockBundleCtrl.createPrefilledStory(getPackageVersionByName('My_Bundle').Id);

            // Verify
            System.assertEquals(o.Id, result.Org_Credential__c);
        }
    }

    @IsTest
    private static void getPrefilledStoryWithDifferentFieldValues() {
        System.runAs(getUser()) {
            // Setup
            User_Story__c us = fetchStoriesByRecordType('User_Story').get(0);

            Project__c p = TestDataFactory.createProject('My Project 2.0', us.Project__r.Deployment_Flow__c, true);
            insert p;

            Release__c r = TestDataFactory.createRelease('My Release 2.0', p.Id);
            insert r;

            us.Project__c = p.Id;
            us.Release__c = r.Id;
            update us;

            // Exercise
            User_Story__c result = LockBundleCtrl.createPrefilledStory(getPackageVersionByName('My_Bundle').Id);

            // Verify
            System.assertEquals(null, result.Project__c);
            System.assertEquals(null, result.Release__c);
        }
    }

    @IsTest
    private static void getPrefilledStoryException() {
        System.runAs(getUser()) {
            // Setup
            String result;

            Artifact_Version__c version = getPackageVersionByName('My_Bundle');
            delete version;

            // Exercise
            try {
                LockBundleCtrl.createPrefilledStory(version.Id);
            } catch (Exception ex) {
                result = ex.getMessage();
            }

            // Verify
            System.assert(String.isNotBlank(result));
        }
    }

    // HELPER

    private static User getUser() {
        User standardUser = [SELECT Id, Username FROM User WHERE Username = 'test_user@myorg.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(standardUser.Username), true, true, true, true, true, true);
        return standardUser;
    }

    private static Artifact_Version__c getPackageVersionByName(String name) {
        return [SELECT Id, Name, Status__c FROM Artifact_Version__c WHERE Name = :name LIMIT 1];
    }

    private static List<User_Story__c> fetchStoriesByRecordType(String developerName) {
        return [
            SELECT Id, Project__c, Release__c, Org_Credential__c, Environment__c, Project__r.Deployment_Flow__c
            FROM User_Story__c
            WHERE RecordType.DeveloperName = :developerName
        ];
    }

    private static User_Story__c createBundleStory() {
        Org__c credential = [SELECT Id, Environment__c FROM Org__c WHERE Name = 'staging 0' LIMIT 1];
        Project__c project = [SELECT Id FROM Project__c WHERE Name = 'MyProject 0' LIMIT 1];
        User_Story__c story = TestDataFactory.createUserStories(
                1,
                'My Parent Story',
                'Approved',
                null,
                project.Id,
                credential.Environment__c,
                credential.Id,
                'Utility'
            )
            .get(0);
        story.Is_Bundle__c = true;

        return story;
    }

    private static void createData() {
        TestUtilities.enableLicenses(10, 10, 10, 10, 10, 100);
        ITestDefaults users = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers().executeDML();
        User standardUser = users.getRunAsUsers().get('Standard')[0];
        System.runAs(standardUser) {
            TestUtilities.assignLicense(String.valueOf(standardUser.Username), true, true, true, true, true);
            ITestDefaults orgCredentialDefaults = new CopadoSetupTestDefaults.OrgCredentialDefaults()
                .setFieldDefaults()
                .setFieldValue(Org__c.SObjectType, Org__c.Name, 'staging')
                .setFieldValue(Org__c.SObjectType, Org__c.Default_Credential__c, true)
                .setFieldValue(Org__c.SObjectType, Org__c.Validated_Date__c, Datetime.now())
                .setFieldValue(Org__c.SObjectType, Org__c.SFDC_Org_ID__c, '00D1i00000095cEEAQ_0050X000007h8hTQAQ_6')
                .setDataSize(Org__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CopadoSetupTestDefaults.OrgCredentialDefaults.class)
                .setFieldValue(Org__c.SObjectType, Org__c.Name, 'dev1')
                .setFieldValue(Org__c.SObjectType, Org__c.Default_Credential__c, true)
                .setFieldValue(Org__c.SObjectType, Org__c.Validated_Date__c, Datetime.now())
                .setFieldValue(Org__c.SObjectType, Org__c.SFDC_Org_ID__c, '00D1i00000095CBEAY_0050X000007h8hTQAQ_3')
                .setDataSize(Org__c.SObjectType, 1)
                .includeDefaults(CopadoUserStoryTestDefaults.PipelineDefaults.class)
                .includeDefaults(CopadoUserStoryTestDefaults.ProjectDefaults.class)
                .includeDefaults(CopadoUserStoryTestDefaults.GitRepositoryDefaults.class)
                .includeDefaults(CopadoUserStoryTestDefaults.ReleaseDefaults.class)
                .setSObjectRelation(
                    Deployment_Flow__c.SObjectType,
                    Git_Repository__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Deployment_Flow__c.Git_Repository__c => 1 }
                )
                .setSObjectRelation(
                    Project__c.SObjectType,
                    Deployment_Flow__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Project__c.Deployment_Flow__c => 1 }
                )
                .setSObjectRelation(
                    Release__c.SObjectType,
                    Project__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Release__c.Project__c => 1 }
                )
                .setDataSize(Git_Repository__c.SObjectType, 1)
                .setDataSize(Deployment_Flow__c.SObjectType, 1)
                .setDataSize(Project__c.SObjectType, 1)
                .setDataSize(Release__c.SObjectType, 1)
                .generateDefaults()
                .executeDML();

            update (List<Org__c>) orgCredentialDefaults.getTestData(Org__c.SObjectType);

            Git_Repository__c createdRepo = (Git_Repository__c) orgCredentialDefaults.getTestData(Git_Repository__c.SObjectType)[0];
            Project__c createdProject = (Project__c) orgCredentialDefaults.getTestData(Project__c.SObjectType)[0];
            Release__c createdRelease = (Release__c) orgCredentialDefaults.getTestData(Release__c.SObjectType)[0];

            Org__c dev1Org = new Org__c();
            Org__c stagingOrg = new Org__c();

            List<Org__c> createdOrgs = (List<Org__c>) orgCredentialDefaults.getTestData(Org__c.SObjectType);
            for (Org__c org : createdOrgs) {
                switch on org.Name {
                    when 'staging 0' {
                        stagingOrg = org;
                    }
                    when 'dev1 0' {
                        dev1Org = org;
                    }
                }
            }

            ITestDefaults gitSnapshot = new CopadoDeploymentWizardTestDefaults.GitBackupDefaults()
                .setFieldDefaults()
                .setFieldValue(Git_Backup__c.SObjectType, Git_Backup__c.Org__c, stagingOrg.Id)
                .setFieldValue(Git_Backup__c.SObjectType, Git_Backup__c.Git_Repository__c, createdRepo.Id)
                .includeDefaults(CopadoDeploymentWizardTestDefaults.GitOrgCommitDefaults.class)
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Org__c, stagingOrg.Id)
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Status__c, 'Complete')
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Git_Operation__c, 'Commit Files')
                .setSObjectRelation(
                    Git_Org_Commit__c.SObjectType,
                    Git_Backup__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Git_Org_Commit__c.Git_Backup__c => 1 }
                )
                .setIncrementalFields(
                    new Map<Schema.SObjectType, Set<Schema.SObjectField>>{
                        Git_Org_Commit__c.SObjectType => new Set<Schema.SObjectField>{ Git_Org_Commit__c.Commit_Id__c }
                    }
                )
                .setDataSize(Git_Backup__c.SObjectType, 1)
                .setDataSize(Git_Org_Commit__c.SObjectType, 2)
                .generateDefaults()
                .includeDefaults(CopadoDeploymentWizardTestDefaults.GitOrgCommitDefaults.class)
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Org__c, stagingOrg.Id)
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Git_Org_Commit__c.Commit_Id__c, 'cmm 2')
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Status__c, 'Complete')
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Git_Operation__c, 'Full Profiles & Permission Sets')
                .setSObjectRelation(
                    Git_Org_Commit__c.SObjectType,
                    Git_Backup__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Git_Org_Commit__c.Git_Backup__c => 1 }
                )
                .setDataSize(Git_Org_Commit__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CopadoDeploymentWizardTestDefaults.GitOrgCommitDefaults.class)
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Org__c, stagingOrg.Id)
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Git_Org_Commit__c.Commit_Id__c, 'cmm 3')
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Status__c, 'Complete')
                .setFieldValue(Git_Org_Commit__c.SObjectType, Git_Org_Commit__c.Git_Operation__c, 'Destructive Changes')
                .setSObjectRelation(
                    Git_Org_Commit__c.SObjectType,
                    Git_Backup__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Git_Org_Commit__c.Git_Backup__c => 1 }
                )
                .setDataSize(Git_Org_Commit__c.SObjectType, 1)
                .generateDefaults()
                .executeDML();

            Git_Org_Commit__c orgCommit1 = new Git_Org_Commit__c();
            Git_Org_Commit__c orgCommit2 = new Git_Org_Commit__c();
            Git_Org_Commit__c orgCommitProfiles = new Git_Org_Commit__c();
            Git_Org_Commit__c orgCommitDestructive = new Git_Org_Commit__c();

            List<Git_Org_Commit__c> orgCommits = (List<Git_Org_Commit__c>) gitSnapshot.getTestData(Git_Org_Commit__c.SObjectType);
            for (Git_Org_Commit__c record : orgCommits) {
                if (record.Commit_Id__c == 'cmm 0' & record.Git_Operation__c == 'Commit Files') {
                    orgCommit1 = record;
                }
                if (record.Commit_Id__c == 'cmm 1' & record.Git_Operation__c == 'Commit Files') {
                    orgCommit2 = record;
                }
                if (record.Git_Operation__c == 'Full Profiles & Permission Sets') {
                    orgCommitProfiles = record;
                }
                if (record.Git_Operation__c == 'Destructive Changes') {
                    orgCommitDestructive = record;
                }
            }

            ITestDefaults stories = new CopadoUserStoryTestDefaults.UserStoryDefaults()
                .setFieldDefaults()
                .setFieldValue(User_Story__c.SObjectType, User_Story__c.Org_Credential__c, stagingOrg.Id)
                .setFieldValue(User_Story__c.SObjectType, User_Story__c.Project__c, createdProject.Id)
                .setFieldValue(User_Story__c.SObjectType, User_Story__c.Release__c, createdRelease.Id)
                .setIncrementalFields(
                    new Map<Schema.SObjectType, Set<Schema.SObjectField>>{
                        User_Story__c.SObjectType => new Set<Schema.SObjectField>{ User_Story__c.User_Story_Title__c }
                    }
                )
                .setDataSize(User_Story__c.SObjectType, 6)
                .generateDefaults()
                .executeDML();

            User_Story__c story1 = new User_Story__c();
            User_Story__c story2 = new User_Story__c();
            User_Story__c story3 = new User_Story__c();
            User_Story__c story4 = new User_Story__c();

            List<User_Story__c> storiesCreated = (List<User_Story__c>) stories.getTestData(User_Story__c.SObjectType);
            for (User_Story__c record : storiesCreated) {
                switch on record.User_Story_Title__c {
                    when 'My new User Story 0' {
                        story1 = record;
                    }
                    when 'My new User Story 1' {
                        story2 = record;
                    }
                    when 'My new User Story 2' {
                        story3 = record;
                    }
                    when 'My new User Story 3' {
                        story4 = record;
                    }
                }
            }

            ITestDefaults userStoryCommitDefaults = new CopadoUserStoryTestDefaults.UserStoryCommitDefaults()
                .setFieldDefaults()
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.User_Story__c, story1.Id)
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.Snapshot_Commit__c, orgCommit1.Id)
                .setDataSize(User_Story_Commit__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CopadoUserStoryTestDefaults.UserStoryCommitDefaults.class)
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.User_Story__c, story2.Id)
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.Snapshot_Commit__c, orgCommit2.Id)
                .setDataSize(User_Story_Commit__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CopadoUserStoryTestDefaults.UserStoryCommitDefaults.class)
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.User_Story__c, story1.Id)
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.Snapshot_Commit__c, orgCommitProfiles.Id)
                .setDataSize(User_Story_Commit__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CopadoUserStoryTestDefaults.UserStoryCommitDefaults.class)
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.User_Story__c, story2.Id)
                .setFieldValue(User_Story_Commit__c.SObjectType, User_Story_Commit__c.Snapshot_Commit__c, orgCommitDestructive.Id)
                .setDataSize(User_Story_Commit__c.SObjectType, 1)
                .generateDefaults()
                .executeDML();

            ITestDefaults deploymentTaskDefaults = new CopadoUserStoryTestDefaults.DeploymentTaskDefaults()
                .setFieldDefaults()
                .setFieldValue(Deployment_Task__c.SObjectType, Deployment_Task__c.User_Story__c, story1.Id)
                .setFieldValue(Deployment_Task__c.SObjectType, Deployment_Task__c.Task_Description__c, 'Deployment Task Description')
                .setFieldValue(Deployment_Task__c.SObjectType, Deployment_Task__c.Type__c, 'Manual Task')
                .setDataSize(Deployment_Task__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CopadoUserStoryTestDefaults.DeploymentTaskDefaults.class)
                .setFieldValue(Deployment_Task__c.SObjectType, Deployment_Task__c.User_Story__c, story2.Id)
                .setFieldValue(Deployment_Task__c.SObjectType, Deployment_Task__c.Task_Description__c, 'Deployment Task Apex')
                .setFieldValue(Deployment_Task__c.SObjectType, Deployment_Task__c.Type__c, 'Apex')
                .setDataSize(Deployment_Task__c.SObjectType, 1)
                .generateDefaults()
                .executeDML();

            Deployment_Task__c deploymentTask1 = new Deployment_Task__c();
            List<Deployment_Task__c> deploymentTasks = (List<Deployment_Task__c>) deploymentTaskDefaults.getTestData(Deployment_Task__c.SObjectType);
            for (Deployment_Task__c record : deploymentTasks) {
                switch on record.Type__c {
                    when 'Apex' {
                        deploymentTask1 = record;
                    }
                }
            }

            Attachment att1 = new Attachment(
                ParentId = orgCommit1.Id,
                Name = 'Metadata',
                Body = Blob.valueOf('[{"t":"EmailTemplate","n":"Template1","s":true,"r":true}, {"t":"EmailTemplate","n":"Template2","s":false}]')
            );

            Attachment att2 = new Attachment(
                ParentId = orgCommit2.Id,
                Name = 'Metadata',
                Body = Blob.valueOf('[{"t":"EmailTemplate","n":"Template1","s":true,"r":false}, {"t":"EmailTemplate","n":"a_Template","s":true}]')
            );

            Attachment fullProfiles = new Attachment(
                ParentId = orgCommitProfiles.Id,
                Name = 'Metadata',
                Body = Blob.valueOf('[{"t":"PermissionSet","n":"Charly_Permission"}]')
            );

            Attachment destructive = new Attachment(
                ParentId = orgCommitDestructive.Id,
                Name = 'Git Deletion',
                Body = Blob.valueOf('[{"n":"Hi","s":true,"b":"","cb":"","r":false,"t":"ApexClass"}]')
            );

            Attachment testOnlyAttachment = new Attachment(
                ParentId = story1.Id,
                Name = 'Test Classes',
                Body = Blob.valueOf('[{"n":"test_class","s":true,"r":false,"ns":""}]')
            );

            Attachment testApexDeploymentTask = new Attachment(
                ParentId = deploymentTask1.Id,
                Name = 'Apex',
                Body = Blob.valueOf('System.debug(\'debug\')')
            );

            insert new List<Attachment>{ att1, att2, fullProfiles, destructive, testOnlyAttachment, testApexDeploymentTask };
            createTestBundle();
        }
    }

    private static void createTestBundle() {
        Map<Id, User_Story__c> selectedUserStories = new Map<Id, User_Story__c>(
            [SELECT Id, Name, Environment__c, Project__r.Deployment_Flow__c, Release__r.Project__r.Deployment_Flow__c FROM User_Story__c LIMIT 4]
        );
        Artifact__c parentBundle = new Artifact__c(
            Name = 'My_Bundle',
            RecordTypeId = Schema.SObjectType.Artifact__c.getRecordTypeInfosByDeveloperName().get('User_Story_Bundle').getRecordTypeId()
        );
        insert parentBundle;
        Artifact_Version__c bundle = new Artifact_Version__c(Name = 'My_Bundle', Artifact__c = parentBundle.Id);

        // Exercise
        String bundleId = UserStoryBundleCtrl.createBundleRecords(
            bundle,
            selectedUserStories.values(),
            testMetadata(),
            testFullProfiles(),
            testDestructive()
        );
    }

    private static List<MetaDataItem> testMetadata() {
        MetaDataItem item = new MetaDataItem();
        item.n = 'Template1';
        item.r = false;
        item.s = true;
        item.t = 'EmailTemplate';

        MetaDataItem item2 = new MetaDataItem();
        item2.n = 'Template2';
        item2.s = true;
        item2.t = 'EmailTemplate';

        MetaDataItem item3 = new MetaDataItem();
        item3.n = 'a_Template';
        item3.s = true;
        item3.t = 'EmailTemplate';

        return new List<MetaDataItem>{ item, item2, item3 };
    }

    private static List<MetaDataItem> testFullProfiles() {
        MetaDataItem item = new MetaDataItem();
        item.n = 'Charly_Permission';
        item.s = true;
        item.t = 'PermissionSet';

        return new List<MetaDataItem>{ item };
    }

    private static List<MetaDataItem> testDestructive() {
        MetaDataItem item = new MetaDataItem();
        item.n = 'Hi';
        item.r = false;
        item.s = true;
        item.t = 'ApexClass';
        item.cb = '';

        return new List<MetaDataItem>{ item };
    }
}