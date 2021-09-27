@IsTest
private class RunCopadoFunctionTest {
    static {
        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(user) {
            assignPermissions(user.Id);
        }
    }

    @TestSetup
    private static void makeData() {
        TestUtilities.assignLicense(UserInfo.getUserName(), true, true, true, true, true);
        insertTestData();
    }

    @IsTest
    private static void execute() {
        // Setup

        setMockHttpResponse();

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(user) {
            FeatureManagement.setPackageIntegerValue('Functions', 1);
        }
        
        // Exercise

        Test.startTest();
        RunCopadoFunction.InvocableVariables variables = new RunCopadoFunction.InvocableVariables();
        variables.functionApiName = 'muleDeploy';
        variables.contextId = [SELECT Id FROM Deployment_Job__c LIMIT 1]?.Id;
        variables.parameters = (List<Parameter>) JSON.deserialize(
            [SELECT Parameters__c FROM Function__c LIMIT 1]
            ?.Parameters__c,
            List<Parameter>.class
        );
        variables.optionsJSON = '[{ "name": "volumeSize", "value": "5" }, { "name": "volumeTTL", "value": "3600" }, { "name": "transactionId", "value": "a1f2o00000GOw2OAAT" }]';

        RunCopadoFunction.execute(new List<RunCopadoFunction.InvocableVariables>{ variables });
        Test.stopTest();

        // Verify

        List<Result__c> results = [SELECT Id FROM Result__c WHERE Job_Type__c = 'muleDeploy' LIMIT 1];
        System.assert(!results.isEmpty(), 'Result was not created before executing the function.');
    }

    @IsTest
    private static void executeWithError() {
        // Setup

        setMockHttpResponse();

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(user) {
            FeatureManagement.setPackageIntegerValue('Functions', 1);
        }
        
        // Exercise

        Test.startTest();
        RunCopadoFunction.InvocableVariables variables = new RunCopadoFunction.InvocableVariables();
        variables.functionApiName = 'unknown';
        variables.contextId = [SELECT Id FROM Deployment_Job__c LIMIT 1]?.Id;
        variables.showValidationErrors = true;

        Exception result;

        try {
            System.runAs(user) {
            RunCopadoFunction.execute(new List<RunCopadoFunction.InvocableVariables>{ variables });
            }
        } catch (Exception ex) {
            result = ex;
        }

        Test.stopTest();

        // Verify
        System.assert(result.getMessage().contains(Label.Function_not_Found), 'The error should come from a non-existing function in the system.');
    }

    @IsTest
    private static void executeWithoutFeatureLicense() {
        // Setup
        Exception expectedException = null;
        setMockHttpResponse();

        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(user) {
            FeatureManagement.setPackageIntegerValue('Functions', 0);
        }

        // Exercise
        Test.startTest();
        RunCopadoFunction.InvocableVariables variables = new RunCopadoFunction.InvocableVariables();
        variables.functionApiName = 'muleDeploy';
        variables.contextId = [SELECT Id FROM Deployment_Job__c LIMIT 1]?.Id;
        variables.showValidationErrors = true;

        try {
            
            System.runAs(user) {
            RunCopadoFunction.execute(new List<RunCopadoFunction.InvocableVariables>{ variables });
            }
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }


        Test.stopTest();


        // Verify
        System.assertNotEquals(null, expectedException);
        System.assert(expectedException.getMessage().contains(expectedException.getMessage()));
    }

    @IsTest
    private static void payloadWithOptions() {
        // Setup

        Function__c function = function();
        String volumeOptions = '[{ "name": "volumeSize", "value": "5" }, { "name": "volumeTTL", "value": "3600" }, { "name": "transactionId", "value": "a1f2o00000GOw2OAAT" }]';

        // Exercise

        Test.startTest();
        FunctionPayload payload = new FunctionPayload(function)
            .parameters((List<Parameter>) JSON.deserialize(function.Parameters__c, List<Parameter>.class))
            .options((List<Parameter>) JSON.deserialize(volumeOptions, List<Parameter>.class));
        Test.stopTest();

        // Verify

        String result = payload.toJson();
        System.assert(result.contains('branchName'), 'branchName parameter was not added to the payload options.');
        System.assert(result.contains('transactionId'), 'transactionId parameter was not added to the payload options.');
        System.assert(result.contains('volumeSize'), 'volumeSize parameter was not added to the payload options.');
        System.assert(result.contains('volumeTTL'), 'volumeTTL parameter was not added to the payload options.');
    }

    // Helpers

    private static void assignPermissions(Id userId) {
        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE
                Name IN ('Copado_User', 'Copado_Functions', 'Copado_Job_Engine')
                AND Id NOT IN (SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :userId)
        ];
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : permissionSets) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSet.Id));
        }
        insert assignments;
    }

    private static Function__c function() {
        return [
            SELECT API_Name__c, Script__c, Image_Name__c, Parameters__c, Options__c, Worker_Size__c
            FROM Function__c
            WHERE API_Name__c = 'muleDeploy'
            LIMIT 1
        ];
    }

    private static void insertTestData() {
        insert new Personal_Settings__c(SetupOwnerId = UserInfo.getUserId(), API_Key__c = DeployAPI.encryptAPIKey('000111222333'));

        Function__c function = new Function__c(
            Name = 'muleDeploy',
            API_Name__c = 'muleDeploy',
            Script__c = 'echo hello world $par1',
            Type__c = 'Custom',
            Parameters__c = '[{"name": "SourceDBName", "defaultValue": "{$Source.Property.DBName}", "required": true},' +
                '{"name": "DestinationDBProvider", "defaultValue": "{$Destination.Property.DB-Provider}", "required": true},' +
                '{"name": "PipelineUsername", "defaultValue": "{$Pipeline.Property.Username}", "required": true},' +
                '{"name": "UserEmail", "defaultValue": "{$User.Property.Email}", "required": true},' +
                '{"name": "LogLevel", "defaultValue": "ERROR", "required": false}]',
            Options__c = '[{"name": "gitUrl", "value": "xxxxxx", "sensitive": true},' +
                '{"name": "gitUsername", "value": "", "sensitive": true},' +
                '{"name": "gitPassword", "value": "", "sensitive": true},' +
                '{"name": "branchName", "value": "", "sensitive": false}]',
            Image_Name__c = 'copadoCore',
            Timeout__c = 5
        );
        insert function;

        List<Environment__c> environments = new List<Environment__c>();
        Environment__c dev1Environment = CMTestMethodUtilities.createEnvironment('DEV-1', '000000000000000001');
        environments.add(dev1Environment);
        Environment__c intEnvironment = CMTestMethodUtilities.createEnvironment('INT', '000000000000000002');
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
        insert pipeline;

        Deployment_Flow_Step__c pipelineConnection = CMTestMethodUtilities.createFlowStep(dev1Environment.Id, intEnvironment.Id, pipeline.Id);
        insert pipelineConnection;

        Project__c project = CMTestMethodUtilities.createProject('PROJECT');
        project.Deployment_Flow__c = pipeline.Id;
        insert project;

        Promotion__c promotion = CMTestMethodUtilities.createPromotion(project.Id, dev1Environment.Id);
        promotion.Source_Org_Credential__c = dev1Credential.Id;
        insert promotion;

        Deployment__c deployment = testMethodUtilities.create('DEPLOYMENT', Datetime.now(), Datetime.now(), dev1Credential.Id, null, 'In progress');
        deployment.Promotion__c = promotion.Id;
        insert deployment;

        Step__c step = testMethodUtilities.create(
            'STEP',
            null,
            '{"functionId":"' +
            function.Id +
            '","functionAPIName":"' +
            function.API_Name__c +
            '","functionParameters":' +
            '[{"name": "SourceDBName", "value": "dbname"},' +
            '{"name": "DestinationDBProvider", "value": "provider"},' +
            '{"name": "PipelineUsername", "value": "username"},' +
            '{"name": "UserEmail", "value": "email"},' +
            '{"name": "LogLevel", "value": "ERROR"}]}',
            deployment.Id,
            0,
            'In progress',
            'Function'
        );
        insert step;

        Destination_Org__c destination = testMethodUtilities.create(deployment.Id, 'In progress', intCredential.Id);
        insert destination;

        Deployment_Job__c job = testMethodUtilities.create(1, destination.Id, null, 'In progress', step.Id);
        insert job;

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
        System_Property__c userProperty = new System_Property__c(
            API_Name__c = 'Email',
            Value__c = 'user@example.com',
            User__c = UserInfo.getUserId()
        );
        properties.add(userProperty);
        insert properties;
    }

    private static void setMockHttpResponse() {
        MockHttpResponseGenerator mockResponse = new MockHttpResponseGenerator(
            200,
            'Complete',
            '{"id": "123123123", "status": "pending", "messages": ["function received and Queued", "executin will start shortly"]}',
            null
        );
        Test.setMock(HttpCalloutMock.class, mockResponse);
    }
}