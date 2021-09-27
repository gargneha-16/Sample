@IsTest
public class PackageImportServiceTest {
    @TestSetup
    public static void makeData() {
        new DataHelper().userSetup();
    }

    @IsTest
    public static void run() {
        System.runAs(getRunAsUser()) {
            // Setup
            DataHelper helper = new DataHelper()
                                    .createRepository()
                                    .createPipeline()
                                    .createJobTemplate()
                                    .mockDefaultTemplates()
                                    .createRequest();

            // Exercise
            String result = new PackageImportService().run(helper.request);
            PackageImportService.Response response = (PackageImportService.Response) JSON.deserialize(result, PackageImportService.Response.class);

            // Verify
            System.assertEquals('OK', response.status, 'Status should be OK.');
            System.assertEquals('Package import started successfully.', response.message, 'Message should be successfully started.');
            System.assertNotEquals(null, response.body.job, 'Job execution should be started.');
        }
    }

    @IsTest
    public static void failure() {
        System.runAs(getRunAsUser()) {
            // Setup
            DataHelper helper = new DataHelper().createRequest();

            // Exercise
            try {
                new PackageImportService().run(helper.request);
            }
            catch (Exception ex) {
                // Verify
                System.assert(String.isNotBlank(ex.getMessage()), 'Error message should be returned.');
            }
        }
    }

    // Helper

    private class DataHelper {
        private Git_Repository__c repository;
        private Deployment_Flow__c pipeline;
        private JobTemplate__c template;
        private CliProxy.CLIWrapper request;

        private DataHelper createRepository() {
            repository = TestDataFactory.createGitRepository();
            insert repository;

            return this;
        }

        private DataHelper createPipeline() {
            pipeline = TestDataFactory.createDeploymentFlow('Test Pipeline', true, repository.Id, true);
            pipeline.Platform__c = 'Salesforce';
            insert pipeline;

            return this;
        }

        private DataHelper createJobTemplate() {
            template = new JobTemplate__c(Name = 'PackageImportTemplate', Version__c = 1);
            insert template;

            return this;
        }

        private DataHelper mockDefaultTemplates() {
            MultiCloudAutomationsSelector.mock = new Map<String, MultiCloudAutomation__mdt>{
                'Salesforce' => new MultiCloudAutomation__mdt(PlatformName__c = 'Salesforce', PackageImportAPIName__c = 'PackageImportTemplate_1')
            };

            return this;
        }

        private DataHelper createRequest() {
            request = new CliProxy.CLIWrapper();
            request.mainService = 'package';
            request.subService = 'import';
            request.body =
                '{"packageNameOrId":"Testpkg", "repositoryId":"' +
                repository?.Id +
                '", "pipelineId":"' +
                pipeline?.Id +
                '", "platformName":"Salesforce"}';

            return this;
        }

        private void userSetup() {
            TestUtilities.enableLicenses(2, 2, 2, 2, 2);
            TestDataFactory.createUsers();

            User u = getRunAsUser();
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

            for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('Copado_User', 'Copado_Job_Engine')]) {
                assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
            }
            insert assignments;

            System.runAs(u) {
                TestUtilities.assignLicense(u.Username, true, true, true, true, true);
            }
        }
    }

    private static User getRunAsUser() {
        return [SELECT Id, Username
                FROM User
                WHERE Profile.Name = 'Standard User' AND Username LIKE '%pstdUser002@amamama.com%'
                LIMIT 1];
    }
}