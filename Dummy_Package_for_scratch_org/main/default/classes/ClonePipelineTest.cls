@IsTest
private with sharing class ClonePipelineTest {
    static {
        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(user) {
            assignPermissions(user.Id);
        }
    }

    @TestSetup
    private static void setup() {
        TestUtilities.assignLicense(UserInfo.getUserName(), true, true, true, true, true);
    }

    @IsTest
    private static void getData() {
        // Setup

        createPipeline('Salesforce');
        Deployment_Flow__c pipeline = pipeline('Salesforce');

        // Exercise

        Pipeline record;
        System.runAs(user()) {
            Test.startTest();
            record = (Pipeline) JSON.deserialize(ClonePipeline.getData(pipeline.Id), Pipeline.class);
            Test.stopTest();
        }

        // Verify

        System.assertEquals(pipeline.Id, record.pipeline.Id, 'Incorrect pipeline record returned.');
        System.assert(!record.connections.isEmpty(), 'No connections were returned for this pipeline.');
        System.assert(!record.environments.isEmpty(), 'No environments were returned for this pipeline.');
        System.assertEquals(null, record.properties, 'System properties should not be returned by this method.');
    }

    @IsTest
    private static void saveSalesforcePipeline() {
        // Setup

        createPipeline('Salesforce');
        Pipeline record = (Pipeline) JSON.deserialize(ClonePipeline.getData(pipeline('Salesforce').Id), Pipeline.class);

        // Exercise

        Id cloneId;
        System.runAs(user()) {
            Test.startTest();

            cloneId = ClonePipeline.saveCopy(JSON.serialize(record));
            Test.stopTest();
        }

        // Verify

        Pipeline clone = (Pipeline) JSON.deserialize(ClonePipeline.getData(cloneId), Pipeline.class);
        System.assert(!clone.connections.isEmpty(), 'No connections were returned for this cloned pipeline.');
        System.assert(clone.environments.isEmpty(), 'Environments should not be cloned for a Salesforce pipeline.');
    }

    @IsTest
    private static void saveNonSalesforcePipeline() {
        // Setup

        createPipeline('Other');
        Pipeline record = (Pipeline) JSON.deserialize(ClonePipeline.getData(pipeline('Other').Id), Pipeline.class);

        // Exercise

        Id cloneId;
        System.runAs(user()) {
            Test.startTest();

            cloneId = ClonePipeline.saveCopy(JSON.serialize(record));
            Test.stopTest();
        }

        // Verify

        Pipeline clone = (Pipeline) JSON.deserialize(ClonePipeline.getData(cloneId), Pipeline.class);
        System.assert(!clone.connections.isEmpty(), 'No connections were returned for this cloned pipeline.');
        System.assert(!clone.environments.isEmpty(), 'No connections were returned for this cloned pipeline.');
    }

    // Helper

    private static Deployment_Flow__c pipeline(String platform) {
        return [SELECT Platform__c FROM Deployment_Flow__c WHERE Platform__c = :platform LIMIT 1];
    }

    private static User user() {
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    private static void assignPermissions(Id userId) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : [
            SELECT Id
            FROM PermissionSet
            WHERE Name IN ('Copado_User', 'Copado_Functions', 'Copado_Job_Engine') AND Id NOT IN (SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :userId)
        ]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSet.Id));
        }
        insert assignments;
    }

    private static void createPipeline(String platform) {
        List<Environment__c> environments = new List<Environment__c>();
        Environment__c dev1Environment = CMTestMethodUtilities.createEnvironment('DEV-1', '000000000000000001');
        dev1Environment.Platform__c = platform;
        environments.add(dev1Environment);
        Environment__c intEnvironment = CMTestMethodUtilities.createEnvironment('INT', '000000000000000002');
        intEnvironment.Platform__c = platform;
        environments.add(intEnvironment);
        insert environments;

        List<Org__c> orgs = new List<Org__c>();
        Org__c userCredential = CMTestMethodUtilities.createOrg(
            'USER-ORG',
            'Production',
            UserInfo.getOrganizationId() +
            '_' +
            UserInfo.getUserId(),
            null,
            UserInfo.getUserName(),
            System.now(),
            null
        );
        userCredential.Oauth_Signature__c = '111222333444';
        orgs.add(userCredential);
        Org__c dev1Credential = CMTestMethodUtilities.createOrg(
            'DEV-1',
            'Production',
            '000000000000000001',
            null,
            null,
            System.now(),
            dev1Environment.Id
        );
        orgs.add(dev1Credential);
        Org__c intCredential = CMTestMethodUtilities.createOrg(
            'INT',
            'Production',
            '000000000000000002',
            null,
            null,
            System.now(),
            intEnvironment.Id
        );
        orgs.add(intCredential);
        insert orgs;

        Deployment_Flow__c pipeline = CMTestMethodUtilities.createFlow('PIPELINE');
        pipeline.Active__c = true;
        pipeline.Platform__c = platform;
        insert pipeline;

        Deployment_Flow_Step__c connection = CMTestMethodUtilities.createFlowStep(dev1Environment.Id, intEnvironment.Id, pipeline.Id);
        insert connection;

        List<System_Property__c> properties = new List<System_Property__c>();
        System_Property__c sourceProperty = new System_Property__c(
            API_Name__c = 'DBName',
            Value__c = 'OracleDB',
            Environment__c = dev1Environment.Id
        );
        properties.add(sourceProperty);
        System_Property__c destinationProperty = new System_Property__c(
            API_Name__c = 'DB-Provider',
            Value__c = 'Oracle',
            Environment__c = intEnvironment.Id
        );
        properties.add(destinationProperty);
        System_Property__c pipelineProperty = new System_Property__c(
            API_Name__c = 'Username',
            Value__c = 'user@oracledb.com',
            Pipeline__c = pipeline.Id
        );
        properties.add(pipelineProperty);
        insert properties;
    }

    private class Pipeline {
        public Deployment_Flow__c pipeline;
        public List<Deployment_Flow_Step__c> connections;
        public List<Environment__c> environments;
        public List<System_Property__c> properties;
    }
}