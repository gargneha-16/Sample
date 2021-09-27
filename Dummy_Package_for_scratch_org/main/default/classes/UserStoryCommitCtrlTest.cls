@IsTest
private with sharing class UserStoryCommitCtrlTest {
    @TestSetup
    private static void setup() {

        TestUtilities.getAllMultilicense();
        User runAsUser = createTestUserWithPermissionSets();

        System.runAs(runAsUser) {
            TestUtilities.assignLicense(String.valueOf(runAsUser.Username), true, true, true, true, true, true);

            Promotion pro =
                    new Promotion(
                            new Release(),
                            new Credential(
                                    new Environment(
                                            new JobTemplate()
                                                    .add( new JobStep() ))),
                            new Credential());

            pro.persist();

            new Deployment(pro)
                    .add( new Step() )
                    .add( new UserStory() )
                .persist();
        }
    }

    @IsTest
    private static void isReCreateFeatureBranchAvailable() {
        System.runAs(getRunAsUser()) {
            // Setup
            Personal_Settings__c personalSettings = Personal_Settings__c.getInstance();
            personalSettings.Disable_Re_Create_Feature_Branch_in_US__c = true;
            upsert personalSettings;

            // Exercise
            Boolean isReCreateFeatureBranchAvailable = UserStoryCommitCtrl.isReCreateFeatureBranchAvailable();

            // Verify
            System.assert(!isReCreateFeatureBranchAvailable, 'Re-create feature branch option should not be available');
        }
    }

    @IsTest
    private static void commitChanges() {
        System.runAs(getRunAsUser()) {
            // Setup
            Id userStoryId = [SELECT Id FROM User_Story__c].Id;

            UserStoryCommitRequest request = new UserStoryCommitRequest();
            request.userStoryId = userStoryId;
            request.changes = changes();
            request.recreateFeatureBranch = true;
            request.executeCommit = true;

            Flow.mockResponse = flowCompletionEvent(true, '', 'Success data 1');

            // Exercise
            Test.startTest();
            JobExecution__c jobExecution = UserStoryCommitCtrl.commitChanges(request);
            List<User_Story_Metadata__c> userStoryMetadata = UserStoryCommitCtrl.getUserStoryMetadata(userStoryId);
            Test.stopTest();

            // Verify
            System.assertEquals('In Progress', jobExecution.Status__C, 'Job execution status before stop test should be In Progress');
            System.assertEquals(
                'Successful',
                [SELECT Status__c FROM JobExecution__c]
                .Status__c,
                'Job execution status after stop test should be Successful'
            );
            System.assertEquals(
                10,
                [SELECT COUNT() FROM User_Story_Metadata__c],
                'Changes should have been created as User_Story_Metadata__c records'
            );
            System.assertEquals(10, userStoryMetadata.size(), 'Changes should have been created as User_Story_Metadata__c records');
            System.assertEquals(
                1,
                [SELECT COUNT() FROM ContentVersion WHERE Title = 'Copado Commit changes.json'],
                'Copado Commit changes.json file should have been upserted'
            );

            // Verify callback
            System.assertNotEquals(
                null,
                [SELECT Latest_Commit_Date__c FROM User_Story__c]
                .Latest_Commit_Date__c,
                'User_Story__c should have been updated with Latest_Commit_Date__c in callback execution'
            );
        }
    }

    @IsTest
    private static void commitChangesException() {
        // Setup & Exercise
        String exceptionMessage;
        Test.startTest();
        try {
            UserStoryCommitRequest request = new UserStoryCommitRequest();
            JobExecution__c jobExecution = UserStoryCommitCtrl.commitChanges(request);
        } catch (Exception e) {
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        // Verify
        System.assert(String.isNotBlank(exceptionMessage), 'Exception should have been thrown');
    }

    private static User createTestUserWithPermissionSets() {
        User result = TestDataFactory.createUsers()[0];

        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name IN ('Copado_User', 'Copado_Functions', 'Copado_Job_Engine')];
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : permissionSets) {
            assignments.add(new PermissionSetAssignment(AssigneeId = result.Id, PermissionSetId = permissionSet.Id));
        }
        insert assignments;

        return result;
    }

    private static User getRunAsUser() {
        return [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
    }

    private static List<UserStoryCommitChange> changes() {
        List<UserStoryCommitChange> result = new List<UserStoryCommitChange>();

        for (Integer i = 0; i < 10; i++) {
            UserStoryCommitChange change = new UserStoryCommitChange();
            change.a = 'add';
            change.n = 'TestClass_' + i;
            change.t = 'ApexClass';
            change.m = 'force-app/main/default';
            change.c = 'category';
            result.add(change);
        }

        return result;
    }

    private static Event__e flowCompletionEvent(Boolean isSuccess, String errorMessage, String data) {
        Event__e result = new Event__e();
        result.Topic_Uri__c = OnJobStepComplete.STEP_ENDPOINT;
        result.Payload__c = Json.serialize(new OnJobStepComplete.EventPayload(isSuccess, errorMessage, data));

        return result;
    }
}