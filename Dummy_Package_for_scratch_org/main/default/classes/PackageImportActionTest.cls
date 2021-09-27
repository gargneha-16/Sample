@IsTest
public class PackageImportActionTest {
    @TestSetup
    private static void makeData() {
        new DataHelper().userSetup();
    }

    @IsTest
    private static void multipleRequests() {
        System.runAs(getRunAsUser()) {
            // Setup
            PackageImportAction.Request request = new PackageImportAction.Request();

            try {
                // Exercise
                PackageImportAction.startImport(new List<PackageImportAction.Request>{ request, request });
            }
            catch (Exception ex) {
                // Verify
                System.assertEquals('Only 1 request is available.', ex.getMessage(), 'Multiple requests should be sent.');
            }
        }
    }

    @IsTest
    private static void repositoryNotFound() {
        System.runAs(getRunAsUser()) {
            // Setup
            PackageImportAction.Request request = new PackageImportAction.Request();

            try {
                // Exercise
                PackageImportAction.startImport(new List<PackageImportAction.Request>{ request });
            }
            catch (Exception ex) {
                // Verify
                System.assertEquals('Repository not found.', ex.getMessage(), 'Repository should be blank/invalid.');
            }
        }
    }

    @IsTest
    private static void pipelineNotFound() {
        System.runAs(getRunAsUser()) {
            // Setup
            DataHelper helper = new DataHelper().createRepository();

            PackageImportAction.Request request = new PackageImportAction.Request();
            request.repositoryId = helper.repository.Id;
            request.pipelineId = helper.repository.Id;

            try {
                // Exercise
                PackageImportAction.startImport(new List<PackageImportAction.Request>{ request });
            } catch (Exception ex) {
                // Verify
                System.assertEquals('Pipeline not found.', ex.getMessage(), 'Pipeline should be invalid.');
            }
        }
    }

    @IsTest
    private static void platformNotFound() {
        System.runAs(getRunAsUser()) {
            // Setup
            DataHelper helper = new DataHelper().createRepository();

            PackageImportAction.Request request = new PackageImportAction.Request();
            request.repositoryId = helper.repository.Id;

            try {
                // Exercise
                PackageImportAction.startImport(new List<PackageImportAction.Request>{ request });
            }
            catch (Exception ex) {
                // Verify
                System.assertEquals('Please provide valid pipeline or platform details.', ex.getMessage(), 'Pipeline and platform should be blank.');
            }
        }
    }

    @IsTest
    private static void templateNotFound() {
        System.runAs(getRunAsUser()) {
            // Setup
            DataHelper helper = new DataHelper().createRepository();

            PackageImportAction.Request request = new PackageImportAction.Request();
            request.repositoryId = helper.repository.Id;
            request.platformName = 'Salesforce';

            try {
                // Exercise
                PackageImportAction.startImport(new List<PackageImportAction.Request>{ request });
            }
            catch (Exception ex) {
                // Verify
                System.assertEquals('Template not found.', ex.getMessage(), 'Template should be absent.');
            }
        }
    }

    @IsTest
    private static void startImport() {
        System.runAs(getRunAsUser()) {
            // Setup
            DataHelper helper = new DataHelper()
                                    .createRepository()
                                    .createPipeline()
                                    .createJobTemplate()
                                    .mockDefaultTemplates();

            PackageImportAction.Request request = new PackageImportAction.Request();
            request.repositoryId = helper.repository.Id;
            request.pipelineId = helper.pipeline.Id;

            // Exercise
            List<PackageImportAction.Response> response = PackageImportAction.startImport(new List<PackageImportAction.Request>{ request });

            // Verify
            System.assertEquals(1, response.size(), 'Response should not be empty');
            System.assertNotEquals(null, response.get(0).job, 'Job execution should be started.');
        }
    }

    // Helper

    private class DataHelper {
        private Git_Repository__c repository;
        private Deployment_Flow__c pipeline;
        private JobTemplate__c template;

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