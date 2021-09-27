@IsTest
private with sharing class RefreshRecentChangesTest {
    @TestSetup
    private static void setup() {
        TestUtilities.getAllMultilicense();
        User runAsUser = createTestUserWithPermissionSets();

        System.runAs(runAsUser) {
            TestUtilities.assignLicense(String.valueOf(runAsUser.Username), true, true, true, true, true, true);

            new Credential().persist();
        }
    }

    @IsTest
    private static void refreshRecentChanges() {
        // Setup
        Org__c org = [SELECT Id FROM Org__c];

        insert new Attachment(Name = 'MetaData', Body = Blob.valueOf('[{"n": "ExampleTest", "t": "ApexClass"}]'), ParentId = org.Id);

        String fixedResponse = fixedResponse();

        MockHttpResponseGenerator mockResponse = new MockHttpResponseGenerator(200, 'Complete', fixedResponse, null);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Exercise
        Test.startTest();
        List<Object> recentChanges = new RefreshRecentChanges(org.Id).execute();
        Test.stopTest();

        // Verify
        String content = (String) ((Map<String, Object>) JSON.deserializeUntyped(fixedResponse)).get('content');
        List<Object> expectedRecords = (List<Object>) ((Map<String, Object>) JSON.deserializeUntyped(content)).get('records');
        System.assertEquals(expectedRecords.size(), recentChanges.size(), 'Recent changes result should match');
    }

    @IsTest
    private static void refreshRecentChangesSinceSpecifiedDateTime() {
        // Setup
        Org__c org = [SELECT Id FROM Org__c LIMIT 1];

        String fixedResponse = fixedResponse();

        MockHttpResponseGenerator mockResponse = new MockHttpResponseGenerator(200, 'Complete', fixedResponse, null);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Exercise
        Test.startTest();
        List<Object> recentChanges = new RefreshRecentChanges(org.Id, DateTime.newInstance(2021, 2, 6)).execute();
        Test.stopTest();

        // Verify
        String content = (String) ((Map<String, Object>) JSON.deserializeUntyped(fixedResponse)).get('content');
        List<Object> expectedRecords = (List<Object>) ((Map<String, Object>) JSON.deserializeUntyped(content)).get('records');
        System.assertEquals(expectedRecords.size(), recentChanges.size(), 'Recent changes result should match');
    }

    @IsTest
    private static void refreshRecentChangesException() {
        // Setup
        Org__c org = [SELECT Id FROM Org__c];

        insert new Attachment(Name = 'MetaData', Body = Blob.valueOf('[{"n": "ExampleTest", "t": "ApexClass"}]'), ParentId = org.Id);

        String fixedResponse = '{' +
            '"error" : "TestError"' +
        '}';

        MockHttpResponseGenerator mockResponse = new MockHttpResponseGenerator(200, 'Complete', fixedResponse, null);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        String exceptionMessage;
        // Exercise
        Test.startTest();
        try {
            List<Object> recentChanges = new RefreshRecentChanges(org.Id).execute();
        } catch(Exception e) {
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();

        // Verify
        System.assertEquals(exceptionMessage, 'TestError', 'Refresh Recent Changes should have thrown an exception');
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

    private static String fixedResponse() {
        return '{' +
            '"statusCode" : 200,' +
            '"content" : "{' +
                '\\"records\\" : [' +
                '{' +
                        '\\"CreatedDate\\": \\"2021-02-07T01:41:26.000+0000\\",' +
                        '\\"CreatedBy\\": {' +
                            '\\"Name\\": \\"User User\\"' +
                        '},' +
                        '\\"LastModifiedDate\\": \\"2021-02-07T01:41:26.000+0000\\",' +
                        '\\"LastModifiedBy\\": {' +
                            '\\"Name\\": \\"User User\\"' +
                        '},' +
                        '\\"IsNameObsolete\\": false,' +
                        '\\"MemberName\\": \\"asdfas\\",' +
                        '\\"MemberType\\": \\"Profile\\"' +
                    '}' +
                ']' +
            '}"' +
        '}';
    }
}