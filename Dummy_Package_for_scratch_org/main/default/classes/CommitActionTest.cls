@IsTest
private with sharing class CommitActionTest {
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
    private static void givenValidUserStoryWhenCommittingChangesThenExecutionIsSuccessful() {

        System.runAs(getRunAsUser()) {
            // Setup
            Id userStoryId = [SELECT Id FROM User_Story__c].Id;
            CommitAction.Request request = new CommitAction.Request();
            request.userStoryId = userStoryId;
            request.changes = changes();
            request.recreateFeatureBranch = true;

            Flow.mockResponse = flowCompletionEvent(true, '', 'Success data 1');

            // Exercise
            Test.startTest();
            CommitAction.Response response = CommitAction.commitChanges(new List<CommitAction.Request>{ request })[0];
            Test.stopTest();

            // Verify
            System.assertEquals('In Progress', response.jobExecution.Status__C, 'Job execution status before stop test should be In Progress');
            System.assertEquals('Successful', [SELECT Status__c FROM JobExecution__c].Status__c, 'Job execution status after stop test should be Successful');
            System.assertEquals(10, [SELECT COUNT() FROM User_Story_Metadata__c], 'Changes should have been created as User_Story_Metadata__c records');
            System.assertEquals(1, [SELECT COUNT() FROM ContentVersion WHERE Title = 'Copado Commit changes.json'], 'Copado Commit changes.json file should have been upserted');
            System.assertEquals(1, [SELECT COUNT() FROM Git_Org_Commit__c], 'One Git Org Commit record should have been created');
            System.assertEquals(1, [SELECT COUNT() FROM User_Story_Commit__c], 'One User Story Commit record should have been created');

            // Verify callback
            System.assertNotEquals(null, [SELECT Latest_Commit_Date__c FROM User_Story__c].Latest_Commit_Date__c, 'User_Story__c should have been updated with Latest_Commit_Date__c in callback execution');
        }
    }

    @IsTest
    private static void givenManyRequestsWhenCommittingThenException() {

        System.runAs(getRunAsUser()) {
            // Setup & Exercise
            String exceptionMessage;
            Test.startTest();
            try {
                List<CommitAction.Response> response = CommitAction.commitChanges(new List<CommitAction.Request>{ new CommitAction.Request(), new CommitAction.Request() });
            } catch (Exception e) {
                exceptionMessage = e.getMessage();
            }
            Test.stopTest();

            // Verify
            System.assert(exceptionMessage.contains(Label.OnlyOneRequestAvailable), 'Only one request available exception should have been thrown');
        }
    }

    @IsTest
    private static void givenLackOfPermissionsWhenCommittingThenException() {

        // Setup
        Id userStoryId = [SELECT Id FROM User_Story__c].Id;
        CommitAction.Request request = new CommitAction.Request();
        request.userStoryId = userStoryId;
        request.changes = changes();
        request.recreateFeatureBranch = true;

        // Exercise
        String exceptionMessage;
        Test.startTest();
        try {
            CommitAction.Response response = CommitAction.commitChanges(new List<CommitAction.Request>{ request })[0];
        } catch (Exception e) {
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        // Verify
        System.assert(exceptionMessage.contains(Label.CanNotPerformThisAction.substringBefore(':')), 'Can not perform this action exception should have been thrown');
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

    private static List<CommitAction.Change> changes() {
        List<CommitAction.Change> result = new List<CommitAction.Change>();

        for (Integer i = 0; i < 10; i++) {
            CommitAction.Change change = new CommitAction.Change();
            change.a = 'add';
            change.n = 'TestClass_' + i;
            change.t = 'ApexClass';
            change.m = 'force-app/main/default';
            change.c = 'category';
            change.j = '{"vk": "6368cb8e-776c-4ad6-9906-444d460715d7"}';
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