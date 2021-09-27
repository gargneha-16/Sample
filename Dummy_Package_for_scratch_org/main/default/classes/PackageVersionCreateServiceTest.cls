@IsTest
private class PackageVersionCreateServiceTest {

    @IsTest
    private static void executeWithMultipleRequest() {
        // Setup
        Exception expectedException = null;

        List<PackageVersionCreateAction.Request> requests = new List<PackageVersionCreateAction.Request> {
            new PackageVersionCreateAction.Request(UserInfo.getUserId(), null),
            new PackageVersionCreateAction.Request(UserInfo.getUserId(), null)
        };


        // Exercise
        try {
            System.runAs(getStandardUser()) {
                PackageVersionCreateAction.create(requests);
            }
        }
        catch (Exception ex) {
            expectedException = ex;
        }


        // Verify

        System.assertNotEquals(null, expectedException, 'Should throw Exception');
        System.assertEquals(Label.MultiplePackageVersionCreationRequestNotAllowed, expectedException.getMessage(), 'Should have Invalid Package Id message');
    }


    @IsTest
    private static void executeWithInValidPackageId() {
        // Setup
        Exception expectedException = null;

        PackageVersionCreateAction.Request request = new PackageVersionCreateAction.Request(UserInfo.getUserId(), null);
        CliProxy.CLIWrapper cliRequest = new CliProxy.CLIWrapper();
        cliRequest.body = JSON.serialize(request);


        // Exercise
        try {
            System.runAs(getStandardUser()) {
                new PackageVersionCreateService().run(cliRequest);
            }
        }
        catch (Exception ex) {
            expectedException = ex;
        }


        // Verify

        System.assertNotEquals(null, expectedException, 'Should throw Exception');
        System.assertEquals(Label.InvalidPackageId, expectedException.getMessage(), 'Should have Invalid Package Id message');
    }


    @IsTest
    private static void executeWithoutJobTemplate() {

        // Setup
        Artifact__c artifact;
        Exception expectedException = null;

        MultiCloudAutomationsSelector.mock = new Map<String, MultiCloudAutomation__mdt> {
            'Other' => new MultiCloudAutomation__mdt( PlatformName__c = 'Other')
        };

        System.runAs(getStandardUser()) {
            Deployment_Flow__c pipeline = new Deployment_Flow__c(Name='Other', Platform__c='Other');
            insert pipeline;

            artifact = new Artifact__c();
            artifact.pipeline__c = pipeline.Id;
            artifact.Package_Type__c = 'First-Generation Package';
            insert artifact;
        }

        PackageVersionCreateAction.Request request = new PackageVersionCreateAction.Request(artifact.Id, null);
        CliProxy.CLIWrapper cliRequest = new CliProxy.CLIWrapper();
        cliRequest.body = JSON.serialize(request);


        // Exercise
        try {
            System.runAs(getStandardUser()) {
                new PackageVersionCreateService().run(cliRequest);
            }
        }
        catch (Exception ex) {
            expectedException = ex;
        }


        // Verify

        System.assertNotEquals(null, expectedException, 'Should throw Exception');
        System.assertEquals(Label.InvalidTemplateId, expectedException.getMessage(), 'Should have Template not found message');
    }


    @IsTest
    private static void executeWithValidJobTemplate() {

        // Setup
        Artifact__c artifact;

        System.runAs(getStandardUser()) {
            Deployment_Flow__c pipeline = new Deployment_Flow__c(Name='Other', Platform__c='Other');
            insert pipeline;

            artifact = new Artifact__c();
            artifact.pipeline__c = pipeline.Id;
            artifact.Package_Type__c = 'First-Generation Package';
            insert artifact;

            JobTemplate__c template = new JobTemplate__c(Name = 'TestVersionCreate', Version__c = 1);
            insert template;
        }

        MultiCloudAutomationsSelector.mock = new Map<String, MultiCloudAutomation__mdt> {
            'Other' => new MultiCloudAutomation__mdt( PlatformName__c = 'Other', PackageVersionCreateApiName__c = 'TestVersionCreate_1')
        };


        List<PackageVersionCreateAction.Request> requests = new List<PackageVersionCreateAction.Request> {
            new PackageVersionCreateAction.Request(artifact.Id, '{"key": "value"}')
        };


        // Exercise
        System.runAs(getStandardUser()) {
            PackageVersionCreateAction.create(requests);
        }


        // Verify
        List<JobExecution__c> jobs = [SELECT DataJson__c FROM JobExecution__c];

        System.assertEquals(1, jobs.size());
        System.assertEquals('{"key": "value"}', jobs[0].DataJson__c);
    }


    // HELPER

    private static User getStandardUser() {
        return [SELECT Username FROM User WHERE Username = 'test_user@myorg.com' LIMIT 1];
    }


    @TestSetup
    private static void createData() {
        TestUtilities.enableLicenses(2, 2, 2, 2, 2, 30);
        User standardUser = new CopadoSetupTestDefaults.UserDefaults()
            						.createRunAsUsers()
            						.executeDML()
            						.getRunAsUsers()
            						.get('Standard')[0];

        System.runAs(standardUser) {
            TestUtilities.assignLicense(String.valueOf(standardUser.Username), true, false, false, false, false);
        }

        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN ('Copado_Functions', 'Copado_Job_Engine')
        ]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = standardUser.Id, PermissionSetId = ps.Id));
        }
        insert assignments;
    }
}