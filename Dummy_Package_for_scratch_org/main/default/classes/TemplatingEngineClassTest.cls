@SuppressWarnings('PMD')
@IsTest
private class TemplatingEngineClassTest {
    @TestSetup
    private static void setupData() {
        createDeploymentJob();
    }

    @IsTest
    private static void parseWithoutContextId() {
        // Setup
        Exception expectedException = null;
        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', 'value') };

        // Exercise
        try {
            new TemplatingEngine(null, parameters).parse();
            new TemplatingEngine('', parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertEquals(null, expectedException);
    }

    @IsTest
    private static void parseWithInvalidParameterName() {
        // Setup
        Exception expectedException = null;
        List<Parameter> parameters = new List<Parameter>{ new Parameter('Invalid Name', 'value') };

        // Exercise
        try {
            new TemplatingEngine('', parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseWithInvalidDynamicExpression() {
        // Setup
        Exception expectedException = null;
        List<Parameter> parameters = new List<Parameter>{ new Parameter('InvalidExpression', '{$Invalid.Expression}') };

        // Exercise
        try {
            new TemplatingEngine('', parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseInvalidExpressionFalsePositive() {
        // Setup
        Exception expectedException = null;

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('json', '{}'),
            new Parameter('json', '{"x": ""}'),
            new Parameter('json', '{".": ""}')
        };

        // Exercise
        try {
            new TemplatingEngine(null, parameters).parse();
        } catch (Exception ex) {
            expectedException = ex;
        }

        // Verify
        System.assertEquals(null, expectedException);
    }

    @IsTest
    private static void parseHardCodedValues() {
        // Setup
        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', 'value') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(null, parameters).parse();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals('value', result[0].value);
    }

    @IsTest
    private static void parseHardCodedDefaultValues() {
        // Setup
        Parameter parameter = new Parameter('key', '');
        parameter.defaultValue = 'value';
        List<Parameter> parameters = new List<Parameter>{ parameter };

        // Exercise
        List<Parameter> result = new TemplatingEngine(null, parameters).parse();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals('value', result[0].value);
    }

    @IsTest
    private static void parseBlankValueForMandatoryProperty() {
        // Setup
        Exception expectedException = null;
        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '').required(true) };

        // Exercise
        try {
            new TemplatingEngine(null, parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseUserTemplate() {
        // Setup
        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '{$User.Name}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(null, parameters).parse();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals(UserInfo.getName(), result[0].value);
        System.assertEquals(false, result[0].sensitive);
    }

    @IsTest
    private static void parseUserTemplateCaseInsensitive() {
        // Setup
        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '{$uSeR.naMe}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(null, parameters).parse();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals(UserInfo.getName(), result[0].value);
    }

    @IsTest
    private static void parseSourceTemplateWithInValidField() {
        // Setup
        Exception expectedException = null;
        Deployment_Job__c job = [SELECT Id FROM Deployment_Job__c LIMIT 1];

        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '{$Source.InvalidField}') };

        // Exercise
        try {
            new TemplatingEngine(job.Id, parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseSourceTemplateField() {
        // Setup

        Deployment_Job__c job = [SELECT Id, Step__r.Deployment__r.From_Org__r.Environment__c FROM Deployment_Job__c LIMIT 1];
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];

        System.runAs(copadoUser) {
            String templateRecordTypeId = Schema.Sobjecttype.Deployment__c.getRecordTypeInfosByDeveloperName()
                .get('Automation_Template')
                .getRecordTypeId();

            Deployment__c deployment = new Deployment__c();
            deployment.Active__c = true;
            deployment.Name = 'Test Deployment';
            deployment.RecordTypeId = templateRecordTypeId;
            insert deployment;

            Environment__c environment = new Environment__c();
            environment.Id = job.Step__r.Deployment__r.From_Org__r.Environment__c;
            environment.Promotion_Override__c = deployment.Id;
            environment.Type__c = 'Sandbox';
            update environment;
        }
        List<Parameter> parameters = new List<Parameter>{
            new Parameter('key', '{$Source.Type__c}'),
            new Parameter('key', '{$Source.Promotion_Override__r.Name}')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(job.Id, parameters).parse();

        // Verify
        System.assertEquals(2, result.size());
        System.assertEquals('Sandbox', result[0].value);
        System.assertEquals(false, result[0].sensitive);
        System.assertEquals('Test Deployment', result[1].value);
        System.assertEquals(false, result[1].sensitive);
    }

    @IsTest
    private static void parseSourceTemplateWithInValidProperty() {
        // Setup
        Exception expectedException = null;
        Deployment_Job__c job = [SELECT Id, Source_Id__c FROM Deployment_Job__c LIMIT 1];

        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '{$Source.Property.Invalid}') };

        // Exercise
        try {
            new TemplatingEngine(job.Id, parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseSourceTemplateWithInSensitiveValue() {
        // Setup
        Deployment_Job__c job = [SELECT Id, Source_Id__c FROM Deployment_Job__c LIMIT 1];

        System_Property__c property = new System_Property__c();
        property.Value__c = 'sql';
        property.API_Name__c = 'DB';
        property.Is_Sensitive__c = false;
        property.ParentId__c = job.Source_Id__c;
        insert property;

        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '{$Source.Property.DB}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(job.Id, parameters).parse();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals('sql', result[0].value);
        System.assertEquals(false, result[0].sensitive);
    }

    @IsTest
    private static void parseSourceTemplateWithSensitiveValue() {
        // Setup
        Deployment_Job__c job = [SELECT Id, Source_Id__c FROM Deployment_Job__c LIMIT 1];
        Test.setMock(WebServiceMock.class, new MdApiMock());
        System_Property__c property = new System_Property__c();
        property.Value__c = 'sql';
        property.API_Name__c = 'DB';
        property.Is_Sensitive__c = true;
        property.ParentId__c = Id.valueOf(job.Source_Id__c);
        insert property;

        SensitivePropertySelector.mock(
            new List<SensitiveProperty__mdt>{ new SensitiveProperty__mdt(DeveloperName = property.Id, Value__c = DeployAPI.encryptAPIKey('sql')) }
        );

        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '{$Source.Property.DB}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(job.Id, parameters).parse();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals('sql', result[0].value);
        System.assertEquals(true, result[0].sensitive);
    }

    @IsTest
    private static void parseMixedTemplateWithInSensitiveValue() {
        // Setup
        Deployment_Job__c job = [SELECT Id, Source_Id__c, Destination_Id__c, Pipeline_Id__c FROM Deployment_Job__c LIMIT 1];

        System_Property__c sourceProperty = new System_Property__c();
        sourceProperty.Value__c = 'source/sql';
        sourceProperty.API_Name__c = 'SourceDB';
        sourceProperty.Is_Sensitive__c = false;
        sourceProperty.ParentId__c = job.Source_Id__c;
        insert sourceProperty;

        System_Property__c destinationProperty = new System_Property__c();
        destinationProperty.Value__c = 'destination/sql';
        destinationProperty.API_Name__c = 'DestinationDB';
        destinationProperty.Is_Sensitive__c = false;
        destinationProperty.ParentId__c = job.Destination_Id__c;
        insert destinationProperty;

        System_Property__c pipelineProperty = new System_Property__c();
        pipelineProperty.Value__c = 'pipeline/sql';
        pipelineProperty.API_Name__c = 'PipelineDB';
        pipelineProperty.Is_Sensitive__c = false;
        pipelineProperty.ParentId__c = job.Pipeline_Id__c;
        insert pipelineProperty;

        System_Property__c userProperty = new System_Property__c();
        userProperty.Value__c = 'user/sql';
        userProperty.API_Name__c = 'UserDB';
        userProperty.Is_Sensitive__c = false;
        userProperty.ParentId__c = UserInfo.getUserId();
        insert userProperty;

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('SourceDB', '{$Source.Property.SourceDB}'),
            new Parameter('DestinationDB', '{$Destination.Property.DestinationDB}'),
            new Parameter('PipelineDB', '{$Pipeline.Property.PipelineDB}'),
            new Parameter('usersql', '{$User.Property.UserDB}'),
            new Parameter('HardcodedKey', 'hardcodedValue')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(job.Id, parameters).parse();

        // Verify
        System.assertEquals(5, result.size());
        System.assertEquals('source/sql', result[0].value);
        System.assertEquals('destination/sql', result[1].value);
        System.assertEquals('pipeline/sql', result[2].value);
        System.assertEquals('user/sql', result[3].value);
        System.assertEquals('hardcodedValue', result[4].value);
    }

    @IsTest
    private static void parseMixedTemplateWithSensitiveValue() {
        // Setup
        Deployment_Job__c job = [SELECT Id, Source_Id__c, Destination_Id__c, Pipeline_Id__c FROM Deployment_Job__c LIMIT 1];
        Test.setMock(WebServiceMock.class, new MdApiMock());

        System_Property__c sourceProperty = new System_Property__c();
        sourceProperty.Value__c = 'source/sql';
        sourceProperty.API_Name__c = 'SourceDB';
        sourceProperty.Is_Sensitive__c = true;
        sourceProperty.ParentId__c = job.Source_Id__c;
        insert sourceProperty;

        System_Property__c destinationProperty = new System_Property__c();
        destinationProperty.Value__c = 'destination/sql';
        destinationProperty.API_Name__c = 'DestinationDB';
        destinationProperty.Is_Sensitive__c = true;
        destinationProperty.ParentId__c = job.Destination_Id__c;
        insert destinationProperty;

        System_Property__c pipelineProperty = new System_Property__c();
        pipelineProperty.Value__c = 'pipeline/sql';
        pipelineProperty.API_Name__c = 'PipelineDB';
        pipelineProperty.Is_Sensitive__c = true;
        pipelineProperty.ParentId__c = job.Pipeline_Id__c;
        insert pipelineProperty;

        System_Property__c userProperty = new System_Property__c();
        userProperty.Value__c = 'user/sql';
        userProperty.API_Name__c = 'UserDB';
        userProperty.Is_Sensitive__c = true;
        userProperty.ParentId__c = UserInfo.getUserId();
        insert userProperty;

        SensitivePropertySelector.mock(
            new List<SensitiveProperty__mdt>{
                new SensitiveProperty__mdt(DeveloperName = sourceProperty.Id, Value__c = DeployAPI.encryptAPIKey(sourceProperty.Value__c)),
                new SensitiveProperty__mdt(DeveloperName = destinationProperty.Id, Value__c = DeployAPI.encryptAPIKey(destinationProperty.Value__c)),
                new SensitiveProperty__mdt(DeveloperName = pipelineProperty.Id, Value__c = DeployAPI.encryptAPIKey(pipelineProperty.Value__c)),
                new SensitiveProperty__mdt(DeveloperName = UserProperty.Id, Value__c = DeployAPI.encryptAPIKey(UserProperty.Value__c))
            }
        );

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('SourceDB', '{$Source.Property.SourceDB}'),
            new Parameter('DestinationDB', '{$Destination.Property.DestinationDB}'),
            new Parameter('PipelineDB', '{$Pipeline.Property.PipelineDB}'),
            new Parameter('UserDB', '{$User.Property.UserDB}'),
            new Parameter('HardcodedKey', 'hardcodedValue')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(job.Id, parameters).parse();

        // Verify
        System.assertEquals(5, result.size());
        System.assertEquals('source/sql', result[0].value);
        System.assertEquals(true, result[0].sensitive);

        System.assertEquals('destination/sql', result[1].value);
        System.assertEquals(true, result[1].sensitive);

        System.assertEquals('pipeline/sql', result[2].value);
        System.assertEquals(true, result[2].sensitive);

        System.assertEquals('user/sql', result[3].value);
        System.assertEquals(true, result[3].sensitive);

        System.assertEquals('hardcodedValue', result[4].value);
        System.assertEquals(false, result[4].sensitive);
    }

    @IsTest
    private static void parseMixedTemplateWithSensitiveValueWithJobStepAsContext() {
        // Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];

        List<Environment__c> environments = [SELECT Id FROM Environment__c];
        Deployment__c deployment = [SELECT Id FROM Deployment__c WHERE Name = 'Test Dev 1'];

        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;

        JobExecution__c execution = new JobExecution__c();
        execution.Template__c = template.Id;
        execution.Deployment__c = deployment.Id;
        execution.Source__c = environments[0].Id;
        execution.Destination__c = environments[1].Id;
        insert execution;

        JobStep__c step = new JobStep__c();
        step.JobExecution__c = execution.Id;
        step.Type__c = 'Manual';
        insert step;
        step = [SELECT Source_Id__c, Destination_Id__c, Pipeline_Id__c FROM JobStep__c WHERE Id = :step.Id];

        Test.setMock(WebServiceMock.class, new MdApiMock());

        System_Property__c sourceProperty = new System_Property__c();
        sourceProperty.Value__c = 'source/sql';
        sourceProperty.API_Name__c = 'SourceDB';
        sourceProperty.Is_Sensitive__c = true;
        sourceProperty.ParentId__c = step.Source_Id__c;
        insert sourceProperty;

        System_Property__c destinationProperty = new System_Property__c();
        destinationProperty.Value__c = 'destination/sql';
        destinationProperty.API_Name__c = 'DestinationDB';
        destinationProperty.Is_Sensitive__c = true;
        destinationProperty.ParentId__c = step.Destination_Id__c;
        insert destinationProperty;

        System_Property__c pipelineProperty = new System_Property__c();
        pipelineProperty.Value__c = 'pipeline/sql';
        pipelineProperty.API_Name__c = 'PipelineDB';
        pipelineProperty.Is_Sensitive__c = true;
        pipelineProperty.ParentId__c = step.Pipeline_Id__c;
        insert pipelineProperty;

        System_Property__c userProperty = new System_Property__c();
        userProperty.Value__c = 'user/sql';
        userProperty.API_Name__c = 'UserDB';
        userProperty.Is_Sensitive__c = true;
        userProperty.ParentId__c = copadoUser.Id;
        insert userProperty;

        SensitivePropertySelector.mock(
            new List<SensitiveProperty__mdt>{
                new SensitiveProperty__mdt(DeveloperName = sourceProperty.Id, Value__c = DeployAPI.encryptAPIKey(sourceProperty.Value__c)),
                new SensitiveProperty__mdt(DeveloperName = destinationProperty.Id, Value__c = DeployAPI.encryptAPIKey(destinationProperty.Value__c)),
                new SensitiveProperty__mdt(DeveloperName = pipelineProperty.Id, Value__c = DeployAPI.encryptAPIKey(pipelineProperty.Value__c)),
                new SensitiveProperty__mdt(DeveloperName = UserProperty.Id, Value__c = DeployAPI.encryptAPIKey(UserProperty.Value__c))
            }
        );

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('SourceDB', '{$Source.Property.SourceDB}'),
            new Parameter('DestinationDB', '{$Destination.Property.DestinationDB}'),
            new Parameter('PipelineDB', '{$Pipeline.Property.PipelineDB}'),
            new Parameter('UserDB', '{$User.Property.UserDB}'),
            new Parameter('HardcodedKey', 'hardcodedValue')
        };

        // Exercise
        List<Parameter> result;
        System.runAs(copadoUser) {
            result = new TemplatingEngine(step.Id, parameters).parse();
        }

        // Verify
        System.assertEquals(5, result.size());
        System.assertEquals('source/sql', result[0].value);
        System.assertEquals(true, result[0].sensitive);

        System.assertEquals('destination/sql', result[1].value);
        System.assertEquals(true, result[1].sensitive);

        System.assertEquals('pipeline/sql', result[2].value);
        System.assertEquals(true, result[2].sensitive);

        System.assertEquals('user/sql', result[3].value);
        System.assertEquals(true, result[3].sensitive);

        System.assertEquals('hardcodedValue', result[4].value);
        System.assertEquals(false, result[4].sensitive);
    }

    @IsTest
    private static void parseSSHRepositoryWithoutRepositoryId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Git_Repository__c repository;

        System.runAs(copadoUser) {
            repository = repository = sshRepository();
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(repository.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('git@github.com:user/repository.git', gitCredential.url);
        System.assertEquals('ssh', gitCredential.type);
        System.assertEquals('publicKey', gitCredential.publicKey);
        System.assertEquals('privateKey', gitCredential.privateKey);
    }

    @IsTest
    private static void parseHTTPSRepositoryWithoutRepositoryId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Git_Repository__c repository;

        System.runAs(copadoUser) {
            repository = httpsRepository();
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(repository.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('https://github.com/user/repository.git', gitCredential.url);
        System.assertEquals('https', gitCredential.type);
        System.assertEquals('username', gitCredential.username);
        System.assertEquals('password', gitCredential.password);
        System.assertEquals('extraheaders', gitCredential.extraheaders);
    }

    @IsTest
    private static void parseRepositoryWithSnapshotIdAsContextId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Git_Backup__c snapshot;

        System.runAs(copadoUser) {
            Git_Repository__c repository = sshRepository();
            Org__c org = [SELECT Id FROM Org__c LIMIT 1];

            snapshot = new Git_Backup__c();
            snapshot.Git_Repository__c = repository.Id;
            snapshot.Org__c = org.Id;
            insert snapshot;
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(snapshot.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('git@github.com:user/repository.git', gitCredential.url);
        System.assertEquals('ssh', gitCredential.type);
        System.assertEquals('publicKey', gitCredential.publicKey);
        System.assertEquals('privateKey', gitCredential.privateKey);
    }

    @IsTest
    private static void parseRepositoryWithInvalidRepositoryId2() {
        //Setup
        Deployment_Job__c job = [SELECT Id, Source_Id__c, Destination_Id__c, Pipeline_Id__c FROM Deployment_Job__c LIMIT 1];

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(job.Id, parameters).parse();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals(null, result[0].value);
    }

    @IsTest
    private static void parseRepositoryWithRepositoryId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Git_Repository__c repository;

        System.runAs(copadoUser) {
            repository = sshRepository();
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(repository.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('git@github.com:user/repository.git', gitCredential.url);
        System.assertEquals('ssh', gitCredential.type);
        System.assertEquals('publicKey', gitCredential.publicKey);
        System.assertEquals('privateKey', gitCredential.privateKey);
    }

    @IsTest
    private static void parseRepositoryWithSnapshotId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Git_Backup__c snapshot;

        System.runAs(copadoUser) {
            Git_Repository__c repository = sshRepository();
            Org__c org = [SELECT Id FROM Org__c LIMIT 1];

            snapshot = new Git_Backup__c();
            snapshot.Git_Repository__c = repository.Id;
            snapshot.Org__c = org.Id;
            insert snapshot;
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(snapshot.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('git@github.com:user/repository.git', gitCredential.url);
        System.assertEquals('ssh', gitCredential.type);
        System.assertEquals('publicKey', gitCredential.publicKey);
        System.assertEquals('privateKey', gitCredential.privateKey);
    }

    @IsTest
    private static void parseRepositoryWithPipelineId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Flow__c pipeline;

        System.runAs(copadoUser) {
            Git_Repository__c repository = sshRepository();

            pipeline = new Deployment_Flow__c();
            pipeline.Git_Repository__c = repository.Id;
            insert pipeline;
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(pipeline.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('git@github.com:user/repository.git', gitCredential.url);
        System.assertEquals('ssh', gitCredential.type);
        System.assertEquals('publicKey', gitCredential.publicKey);
        System.assertEquals('privateKey', gitCredential.privateKey);
    }

    @IsTest
    private static void parseRepositoryWithDeploymentId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment__c deployment;

        System.runAs(copadoUser) {
            Git_Repository__c repository = sshRepository();

            Deployment_Flow__c pipeline = new Deployment_Flow__c();
            pipeline.Git_Repository__c = repository.Id;
            pipeline.Active__c = true;
            pipeline.Main_Branch__c = 'master';
            insert pipeline;

            Project__c project = new Project__c();
            project.Deployment_Flow__c = pipeline.Id;
            insert project;

            Promotion__c promotion = new Promotion__c();
            promotion.Project__c = project.Id;
            insert promotion;

            deployment = new Deployment__c();
            deployment.Promotion__c = promotion.Id;
            insert deployment;
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(deployment.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('git@github.com:user/repository.git', gitCredential.url);
        System.assertEquals('ssh', gitCredential.type);
        System.assertEquals('publicKey', gitCredential.publicKey);
        System.assertEquals('privateKey', gitCredential.privateKey);
    }

    @IsTest
    private static void parseRepositoryWithUserStoryId() {
        //Setup
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        User_Story__c userStory;

        System.runAs(copadoUser) {
            Git_Repository__c repository = sshRepository();

            Deployment_Flow__c pipeline = new Deployment_Flow__c();
            pipeline.Git_Repository__c = repository.Id;
            pipeline.Active__c = true;
            pipeline.Main_Branch__c = 'master';
            insert pipeline;

            Project__c project = new Project__c();
            project.Deployment_Flow__c = pipeline.Id;
            insert project;

            userStory = new User_Story__c();
            userStory.Project__c = project.Id;
            insert userStory;
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('Git_Json', '{$Context.Repository.Credential}') };

        // Exercise
        List<Parameter> result = new TemplatingEngine(userStory.Id, parameters).parse();

        // Verify
        RepositoryExpression.Credential gitCredential = (RepositoryExpression.Credential) JSON.deserialize(
            result[0].value,
            RepositoryExpression.Credential.class
        );
        System.assertEquals(1, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals('git@github.com:user/repository.git', gitCredential.url);
        System.assertEquals('ssh', gitCredential.type);
        System.assertEquals('publicKey', gitCredential.publicKey);
        System.assertEquals('privateKey', gitCredential.privateKey);
    }

    @IsTest
    private static void parseSObjectExpression() {
        //Setup
        Account parentAccount = new Account();
        parentAccount.Name = 'Parent Account';
        insert parentAccount;

        Account account = new Account();
        account.ParentId = parentAccount.Id;
        account.Name = 'Child Account';
        insert account;

        Contact c = new Contact();
        c.LastName = 'Contact';
        c.AccountId = account.Id;
        insert c;

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('ContactName', '{$Context.LastName}'),
            new Parameter('AccountName', '{$Context.Account.Name}'),
            new Parameter('ParentAccountName', '{$Context.Account.Parent.Name}')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(c.Id, parameters).parse();

        // Verify
        System.assertEquals(3, result.size());
        System.assertEquals('Contact', result[0].value);
        System.assertEquals('Child Account', result[1].value);
        System.assertEquals('Parent Account', result[2].value);
    }

    @IsTest
    private static void parseSObjectExpressionWithInvalidFields() {
        //Setup
        Exception expectedException = null;
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Account account = new Account();
        account.Name = 'Test Account';
        insert account;

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('AccountName', '{$Context.InvaildField}'),
            new Parameter('UserName', '{$' + copadoUser.Id + '.Name}')
        };

        // Exercise
        try {
            new TemplatingEngine(account.Id, parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseSObjectExpressionWithExecutionParent() {
        //Setup
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        JobStep__c step1;

        Test.startTest();
        System.runAs(copadoUser) {
            Deployment__c deployment = [SELECT Id FROM Deployment__c WHERE Name = 'Test Dev 1'];

            JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
            insert template;

            JobExecution__c execution = new JobExecution__c();
            execution.Template__c = template.Id;
            execution.Deployment__c = deployment.Id;
            insert execution;

            step1 = new JobStep__c();
            step1.Name = 'Step 1';
            step1.Type__c = 'Manual';
            step1.JobExecution__c = execution.Id;
            insert step1;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('branch', '{$Job.ExecutionParent.Name}')
        };

        // Exercise
        List<Parameter> result;
        System.runAs(copadoUser) {
            result = new TemplatingEngine(step1.Id, parameters).parse();
        }
        Test.stopTest();

        // Verify
        System.assertEquals(1, result.size());
        System.assertEquals('Test Dev 1', result[0].value);
    }

    @IsTest
    private static void parseStepExpressionWithInvalidField() {
        //Setup
        Exception expectedException = null;
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Step__c firstStep;
        Step__c secondStep;

        System.runAs(copadoUser) {
            firstStep = [SELECT Id, Order__c, Branch__c, Deployment__c FROM Step__c LIMIT 1];
            firstStep.Branch__c = 'main';
            update firstStep;

            secondStep = TestDataFactory.createStep(firstStep.Deployment__c, 'Step 2', 'Automation', 'Not Started', 2, null, '');
            insert secondStep;
        }

        List<Parameter> parameters = new List<Parameter>{ new Parameter('PrevStepBranch', '{$Context.PrevStep.InValidFied}') };

        // Exercise
        try {
            new TemplatingEngine(secondStep.Id, parameters).parse();
        } catch (CopadoFunctionException ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseFirstStepExpression() {
        //Setup
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Job__c firstJob;
        Deployment_Job__c secondJob;

        Test.startTest();
        System.runAs(copadoUser) {
            Step__c firstStep = [SELECT Id, Order__c, Branch__c, Deployment__c FROM Step__c LIMIT 1];
            Deployment__c deployment = new Deployment__c();
            deployment.Id = firstStep.Deployment__c;
            deployment.Description__c = 'Sample Deployment';
            update deployment;

            firstStep.Branch__c = 'main';
            firstStep.JsonResult__c = '{ "user_stories": ["US-0001","US-00003"], "count": 2, "target_brach": "main", "promotion_brach":"release/v1.0", "user": {"name": "logedInUser"} }';
            update firstStep;

            Step__c secondStep = TestDataFactory.createStep(firstStep.Deployment__c, 'Step 2', 'Automation', 'Not Started', 2, null, '');
            insert secondStep;

            Destination_Org__c destinationOrg = [SELECT Id FROM Destination_Org__c LIMIT 1];

            firstJob = new Deployment_Job__c(Step__c = firstStep.Id, Destination_Org__c = destinationOrg.Id);
            insert firstJob;

            secondJob = new Deployment_Job__c(Step__c = secondStep.Id, Destination_Org__c = destinationOrg.Id);
            insert secondJob;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('branch', '{$Job.FirstStep.Branch__c}'),
            new Parameter('description', '{$Job.FirstStep.Deployment__r.Description__c}'),
            new Parameter('user_stories', '{$Job.FirstStep.JSONResult.user_stories}'),
            new Parameter('count', '{$Job.FirstStep.JSONResult.count}'),
            new Parameter('userName', '{$Job.FirstStep.JSONResult.user.name}'),
            new Parameter('invalidProperty', '{$Job.FirstStep.JSONResult.user.invalidProperty}')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(secondJob.Id, parameters).parse();
        Test.stopTest();

        // Verify
        System.assertEquals(6, result.size());
        System.assertEquals('main', result[0].value);
        System.assertEquals(false, result[0].sensitive);
        System.assertEquals('Sample Deployment', result[1].value);
        System.assertEquals(false, result[1].sensitive);
        System.assertEquals('["US-0001","US-00003"]', result[2].value);
        System.assertEquals('2', result[3].value);
        System.assertEquals('logedInUser', result[4].value);
        System.assertEquals(null, result[5].value);
    }

    @IsTest
    private static void parsePrevStepExpression() {
        //Setup
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Job__c firstJob;
        Deployment_Job__c secondJob;

        Test.startTest();
        System.runAs(copadoUser) {
            Step__c firstStep = [SELECT Id, Order__c, Branch__c, Deployment__c FROM Step__c LIMIT 1];
            Deployment__c deployment = new Deployment__c();
            deployment.Id = firstStep.Deployment__c;
            deployment.Description__c = 'Sample Deployment';
            update deployment;

            firstStep.Branch__c = 'main';
            firstStep.JsonResult__c = '{ "user_stories": ["US-0001","US-00003"], "count": 2, "target_brach": "main", "promotion_brach":"release/v1.0", "user": {"name": "logedInUser"} }';
            update firstStep;

            Step__c secondStep = TestDataFactory.createStep(firstStep.Deployment__c, 'Step 2', 'Automation', 'Not Started', 2, null, '');
            insert secondStep;

            Destination_Org__c destinationOrg = [SELECT Id FROM Destination_Org__c LIMIT 1];

            firstJob = new Deployment_Job__c(Step__c = firstStep.Id, Destination_Org__c = destinationOrg.Id);
            insert firstJob;

            secondJob = new Deployment_Job__c(Step__c = secondStep.Id, Destination_Org__c = destinationOrg.Id);
            insert secondJob;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('branch', '{$Job.PrevStep.Branch__c}'),
            new Parameter('description', '{$Job.PrevStep.Deployment__r.Description__c}'),
            new Parameter('user_stories', '{$Job.PrevStep.JSONResult.user_stories}'),
            new Parameter('count', '{$Job.PrevStep.JSONResult.count}'),
            new Parameter('userName', '{$Job.PrevStep.JSONResult.user.name}'),
            new Parameter('invalidProperty', '{$Job.PrevStep.JSONResult.user.invalidProperty}')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(secondJob.Id, parameters).parse();
        Test.stopTest();

        // Verify
        System.assertEquals(6, result.size());
        System.assertEquals('main', result[0].value);
        System.assertEquals(false, result[0].sensitive);
        System.assertEquals('Sample Deployment', result[1].value);
        System.assertEquals(false, result[1].sensitive);
        System.assertEquals('["US-0001","US-00003"]', result[2].value);
        System.assertEquals('2', result[3].value);
        System.assertEquals('logedInUser', result[4].value);
        System.assertEquals(null, result[5].value);
    }

    @IsTest
    private static void parseNextStepExpression() {
        //Setup
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Job__c firstJob;
        Deployment_Job__c secondJob;

        Test.startTest();
        System.runAs(copadoUser) {
            Step__c firstStep = [SELECT Id, Order__c, Branch__c, Deployment__c FROM Step__c LIMIT 1];
            Deployment__c deployment = new Deployment__c();
            deployment.Id = firstStep.Deployment__c;
            deployment.Description__c = 'Sample Deployment';
            update deployment;

            Step__c secondStep = TestDataFactory.createStep(firstStep.Deployment__c, 'Step 2', 'Automation', 'Not Started', 2, null, '');
            secondStep.Branch__c = 'main';
            secondStep.JsonResult__c = '{ "user_stories": ["US-0001","US-00003"], "count": 2, "target_brach": "main", "promotion_brach":"release/v1.0", "user": {"name": "logedInUser"} }';
            insert secondStep;

            Destination_Org__c destinationOrg = [SELECT Id FROM Destination_Org__c LIMIT 1];

            firstJob = new Deployment_Job__c(Step__c = firstStep.Id, Destination_Org__c = destinationOrg.Id);
            insert firstJob;

            secondJob = new Deployment_Job__c(Step__c = secondStep.Id, Destination_Org__c = destinationOrg.Id);
            insert secondJob;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('branch', '{$Job.NextStep.Branch__c}'),
            new Parameter('description', '{$Job.NextStep.Deployment__r.Description__c}'),
            new Parameter('user_stories', '{$Job.NextStep.JSONResult.user_stories}'),
            new Parameter('count', '{$Job.NextStep.JSONResult.count}'),
            new Parameter('userName', '{$Job.NextStep.JSONResult.user.name}'),
            new Parameter('invalidProperty', '{$Job.NextStep.JSONResult.user.invalidProperty}')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(firstJob.Id, parameters).parse();
        Test.stopTest();

        // Verify
        System.assertEquals(6, result.size());
        System.assertEquals('main', result[0].value);
        System.assertEquals(false, result[0].sensitive);
        System.assertEquals('Sample Deployment', result[1].value);
        System.assertEquals(false, result[1].sensitive);
        System.assertEquals('["US-0001","US-00003"]', result[2].value);
        System.assertEquals('2', result[3].value);
        System.assertEquals('logedInUser', result[4].value);
        System.assertEquals(null, result[5].value);
    }

    @IsTest
    private static void parseLastStepExpression() {
        //Setup
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Job__c firstJob;
        Deployment_Job__c secondJob;

        Test.startTest();
        System.runAs(copadoUser) {
            Step__c firstStep = [SELECT Id, Order__c, Branch__c, Deployment__c FROM Step__c LIMIT 1];
            Deployment__c deployment = new Deployment__c();
            deployment.Id = firstStep.Deployment__c;
            deployment.Description__c = 'Sample Deployment';
            update deployment;

            Step__c secondStep = TestDataFactory.createStep(firstStep.Deployment__c, 'Step 2', 'Automation', 'Not Started', 2, null, '');
            secondStep.Branch__c = 'main';
            secondStep.JsonResult__c = '{ "user_stories": ["US-0001","US-00003"], "count": 2, "target_brach": "main", "promotion_brach":"release/v1.0", "user": {"name": "logedInUser"} }';
            insert secondStep;

            Destination_Org__c destinationOrg = [SELECT Id FROM Destination_Org__c LIMIT 1];

            firstJob = new Deployment_Job__c(Step__c = firstStep.Id, Destination_Org__c = destinationOrg.Id);
            insert firstJob;

            secondJob = new Deployment_Job__c(Step__c = secondStep.Id, Destination_Org__c = destinationOrg.Id);
            insert secondJob;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('branch', '{$Job.LastStep.Branch__c}'),
            new Parameter('description', '{$Job.LastStep.Deployment__r.Description__c}'),
            new Parameter('user_stories', '{$Job.LastStep.JSONResult.user_stories}'),
            new Parameter('count', '{$Job.LastStep.JSONResult.count}'),
            new Parameter('userName', '{$Job.LastStep.JSONResult.user.name}'),
            new Parameter('invalidProperty', '{$Job.LastStep.JSONResult.user.invalidProperty}')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(firstJob.Id, parameters).parse();
        Test.stopTest();

        // Verify
        System.assertEquals(6, result.size());
        System.assertEquals('main', result[0].value);
        System.assertEquals(false, result[0].sensitive);
        System.assertEquals('Sample Deployment', result[1].value);
        System.assertEquals(false, result[1].sensitive);
        System.assertEquals('["US-0001","US-00003"]', result[2].value);
        System.assertEquals('2', result[3].value);
        System.assertEquals('logedInUser', result[4].value);
        System.assertEquals(null, result[5].value);
    }

    @IsTest
    private static void parseNamedStepExpression() {
        //Setup
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Job__c firstJob;
        Deployment_Job__c secondJob;

        Test.startTest();
        System.runAs(copadoUser) {
            Step__c firstStep = [SELECT Id, Order__c, Branch__c, Deployment__c FROM Step__c LIMIT 1];
            Deployment__c deployment = new Deployment__c();
            deployment.Id = firstStep.Deployment__c;
            deployment.Description__c = 'Sample Deployment';
            update deployment;

            Step__c secondStep = TestDataFactory.createStep(firstStep.Deployment__c, 'Step 2', 'Automation', 'Not Started', 2, null, '');
            secondStep.Branch__c = 'main';
            secondStep.JsonResult__c = '{ "user_stories": ["US-0001","US-00003"], "count": 2, "target_brach": "main", "promotion_brach":"release/v1.0", "user": {"name": "logedInUser"} }';
            insert secondStep;

            Destination_Org__c destinationOrg = [SELECT Id FROM Destination_Org__c LIMIT 1];

            firstJob = new Deployment_Job__c(Step__c = firstStep.Id, Destination_Org__c = destinationOrg.Id);
            insert firstJob;

            secondJob = new Deployment_Job__c(Step__c = secondStep.Id, Destination_Org__c = destinationOrg.Id);
            insert secondJob;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('branch', '{$Job.Step.Step 2.Branch__c}'),
            new Parameter('description', '{$Job.Step.Step 2.Deployment__r.Description__c}'),
            new Parameter('user_stories', '{$Job.Step.Step 2.JSONResult.user_stories}'),
            new Parameter('count', '{$Job.Step.Step 2.JSONResult.count}'),
            new Parameter('userName', '{$Job.Step.Step 2.JSONResult.user.name}'),
            new Parameter('invalidProperty', '{$Job.Step.Step 2.JSONResult.user.invalidProperty}')
        };

        // Exercise
        List<Parameter> result = new TemplatingEngine(firstJob.Id, parameters).parse();
        Test.stopTest();

        // Verify
        System.assertEquals(6, result.size());
        System.assertEquals('main', result[0].value);
        System.assertEquals(false, result[0].sensitive);
        System.assertEquals('Sample Deployment', result[1].value);
        System.assertEquals(false, result[1].sensitive);
        System.assertEquals('["US-0001","US-00003"]', result[2].value);
        System.assertEquals('2', result[3].value);
        System.assertEquals('logedInUser', result[4].value);
        System.assertEquals(null, result[5].value);
    }

    @IsTest
    private static void parseNamedStepExpressionWithJobStepAsContext() {
        //Setup
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        JobStep__c step1;

        Test.startTest();
        System.runAs(copadoUser) {
            Deployment__c deployment = [SELECT Id FROM Deployment__c WHERE Name = 'Test Dev 1'];

            JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
            insert template;

            JobExecution__c execution = new JobExecution__c();
            execution.Template__c = template.Id;
            execution.Deployment__c = deployment.Id;
            insert execution;

            step1 = new JobStep__c();
            step1.Name = 'Step 1';
            step1.Type__c = 'Manual';
            step1.JobExecution__c = execution.Id;
            insert step1;

            JobStep__c step2 = new JobStep__c();
            step2.Name = 'Step 2';
            step2.Type__c = 'Manual';
            step2.ResultDataJson__c = '{ "user_stories": ["US-0001","US-00003"], "count": 2, "target_brach": "main", "promotion_brach":"release/v1.0", "user": {"name": "logedInUser"} }';

            step2.JobExecution__c = execution.Id;
            insert step2;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('branch', '{$Job.Step.Step 2.Type__c}'),
            new Parameter('description', '{$Job.Step.Step 2.JobExecution__r.Deployment__r.Name}'),
            new Parameter('user_stories', '{$Job.Step.Step 2.JSONResult.user_stories}'),
            new Parameter('count', '{$Job.Step.Step 2.JSONResult.count}'),
            new Parameter('userName', '{$Job.Step.Step 2.JSONResult.user.name}'),
            new Parameter('invalidProperty', '{$Job.Step.Step 2.JSONResult.user.invalidProperty}')
        };

        // Exercise
        List<Parameter> result;
        System.runAs(copadoUser) {
            result = new TemplatingEngine(step1.Id, parameters).parse();
        }
        Test.stopTest();

        // Verify
        System.assertEquals(6, result.size());
        System.assertEquals('Manual', result[0].value);
        System.assertEquals(false, result[0].sensitive);
        System.assertEquals('Test Dev 1', result[1].value);
        System.assertEquals(false, result[1].sensitive);
        System.assertEquals('["US-0001","US-00003"]', result[2].value);
        System.assertEquals('2', result[3].value);
        System.assertEquals('logedInUser', result[4].value);
        System.assertEquals(null, result[5].value);
    }

    @IsTest
    private static void parseOrgCredentialWithInvalidRecordId() {
        // Setup
        Exception expectedException = null;

        List<Parameter> parameters = new List<Parameter>{ new Parameter('key', '{$Context.Credential.Endpoint}') };

        // Exercise
        try {
            new TemplatingEngine(UserInfo.getUserId(), parameters).parse();
        } catch (Exception ex) {
            expectedException = ex;
        }

        // Verify
        System.assertNotEquals(null, expectedException);
    }

    @IsTest
    private static void parseOrgCredentialWithRecordId() {
        // Setup
        Test.setMock(HttpCalloutMock.class, new WebHookMock());
        Environment__c environment;

        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];

        System.runAs(copadoUser) {
            environment = new Environment__c();
            environment.Type__c = 'Sandbox';
            insert environment;

            Org__c defaultOrg = new Org__c();
            defaultOrg.Environment__c = environment.Id;
            defaultOrg.Default_Credential__c = true;
            insert defaultOrg;
        }

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('key', '{$Context.Credential.SessionId}'),
            new Parameter('key', '{$Context.Credential.Endpoint}')
        };

        // Exercise
        Test.startTest();
            List<Parameter> result = new TemplatingEngine(environment.Id, parameters).parse();
        Test.stopTest();

        // Verify
        System.assertEquals(2, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals(true, result[1].sensitive);
        System.assertEquals('sessionId', result[0].value);
        System.assertEquals('https://copadodev.salesforce.com/services/Soap/u/49.0/00D09000007GB3WEAW', result[1].value);
    }

    @IsTest
    private static void parseOrgCredentialWithJobContextId() {
        // Setup
        Test.setMock(HttpCalloutMock.class, new WebHookMock());
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Job__c job = [SELECT Id, Source_Id__c FROM Deployment_Job__c LIMIT 1];

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('source', '{$Source.Credential.SessionId}'),
            new Parameter('destination', '{$Destination.Credential.Endpoint}')
        };

        // Exercise
        List<Parameter> result;
        Test.startTest();
        System.runAs(copadoUser) {
            result = new TemplatingEngine(job.Id, parameters).parse();
        }
        Test.stopTest();

        // Verify
        System.assertEquals(2, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals(true, result[1].sensitive);
        System.assertEquals('sessionId', result[0].value);
        System.assertEquals('https://copadodev.salesforce.com/services/Soap/u/49.0/00D09000007GB3WEAW', result[1].value);
    }

    @IsTest
    private static void parseOrgCredentialWithStepContextId() {
        // Setup
        Test.setMock(HttpCalloutMock.class, new WebHookMock());
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        List<Environment__c> environments = [SELECT Id FROM Environment__c];

        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;
        JobExecution__c execution = new JobExecution__c();
        execution.Template__c = template.Id;
        execution.Source__c = environments[0].Id;
        execution.Destination__c = environments[1].Id;
        insert execution;

        JobStep__c step = new JobStep__c();
        step.JobExecution__c = execution.Id;
        step.Type__c = 'Manual';
        insert step;

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('source', '{$Source.Credential.SessionId}'),
            new Parameter('destination', '{$Destination.Credential.Endpoint}')
        };

        // Exercise
        List<Parameter> result;
        Test.startTest();
        System.runAs(copadoUser) {
            result = new TemplatingEngine(step.Id, parameters).parse();
        }
        Test.stopTest();

        // Verify
        System.assertEquals(2, result.size());
        System.assertEquals(true, result[0].sensitive);
        System.assertEquals(true, result[1].sensitive);
        System.assertEquals('sessionId', result[0].value);
        System.assertEquals('https://copadodev.salesforce.com/services/Soap/u/49.0/00D09000007GB3WEAW', result[1].value);
    }

    @IsTest
    private static void parseOrgCredentialWithCalloutError() {
        // Setup
        Exception expectedException = null;

        Test.setMock(HttpCalloutMock.class, new WebHookMock(401));
        User copadoUser = [SELECT Id FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        Deployment_Job__c job = [SELECT Id, Source_Id__c FROM Deployment_Job__c LIMIT 1];

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('source', '{$Source.Credential.SessionId}'),
            new Parameter('destination', '{$Destination.Credential.Endpoint}')
        };

        // Exercise
        Test.startTest();
        try {
            System.runAs(copadoUser) {
                new TemplatingEngine(job.Id, parameters).parse();
            }
        } catch (Exception ex) {
            expectedException = ex;
        }
        Test.stopTest();

        // Verify
        System.assertNotEquals(null, expectedException);
        System.assertEquals(Label.InvalidRequest, expectedException.getMessage());
    }

    @IsTest
    private static void parseSObjectExpressionWithJsonFields() {
        //Setup
        Deployment__c deployment = [SELECT Id FROM Deployment__c WHERE Name = 'Test Dev 1'];

        JobTemplate__c template = new JobTemplate__c(Name = 'Sample', Version__c = 1);
        insert template;

        JobExecution__c execution = new JobExecution__c();
        execution.Template__c = template.Id;
        execution.Deployment__c = deployment.Id;
        execution.DataJson__c = '{ "key1": "value1", "nested": { "key2": "value2.1" }, "key3": ["US-0001","US-00003"] }';
        insert execution;

        JobStep__c step = new JobStep__c();
        step.JobExecution__c = execution.Id;
        step.Type__c = 'Manual';
        insert step;

        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];

        List<Parameter> parameters = new List<Parameter>{
            new Parameter('key1', '{$Context.JobExecution__r.DataJson.key1}'),
            new Parameter('key2', '{$Context.JobExecution__r.DataJson.nested.key2}'),
            new Parameter('key3', '{$Context.JobExecution__r.DataJson.key3}')
        };

        // Exercise
        List<Parameter> result;
        System.runAs(copadoUser) {
            result = new TemplatingEngine(step.Id, parameters).parse();
        }

        // Verify
        System.assertEquals(3, result.size());
        System.assertEquals('value1', result[0].value);
        System.assertEquals('value2.1', result[1].value);
        System.assertEquals('["US-0001","US-00003"]', result[2].value);
    }

    // HELPER

    private static void createDeploymentJob() {
        List<User> users = TestDataFactory.createUsers();
        User copadoUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.enableLicenses(2, 2, 2, 2, 2);
        FeatureManagement.setPackageIntegerValue('CBM_Branches', 2);
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('Copado_User', 'Copado_Job_Engine', 'Copado_Functions')]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = users[0].Id, PermissionSetId = ps.Id));
        }
        insert assignments;

        System.runAs(copadoUser) {
            TestUtilities.assignLicense(String.valueOf(copadoUser.Username), true, true, true, true, true);
            List<Environment__c> environments = TestDataFactory.createEnvironments(3);

            List<Org__c> orgs = TestDataFactory.createOrgCredentials(2, copadoUser.Username, environments);

            String advancedDeploymentRecordTypeId = Schema.Sobjecttype.Deployment__c.getRecordTypeInfosByDeveloperName()
                .get('Advanced_multi_step')
                .getRecordTypeId();
            Deployment_Flow__c pipeline = TestDataFactory.createDeploymentFlow('Test Pipeline', true, null, false);
            insert pipeline;

            Project__c project = TestDataFactory.createProject('test project', pipeline.Id, false);
            insert project;

            Promotion__c promotion = new Promotion__c();
            promotion.Project__c = project.Id;
            insert promotion;

            Deployment__c advancedDeployment = TestDataFactory.createDeployment('Test Dev 1', advancedDeploymentRecordTypeId, orgs[1].Id);
            advancedDeployment.Promotion__c = promotion.Id;
            insert advancedDeployment;

            Step__c step = TestDataFactory.createStep(advancedDeployment.Id, 'Step 1', 'Automation', 'Not Started', 1, null, '');
            insert step;

            Destination_Org__c destinationOrg = TestDataFactory.createDestinationOrg(advancedDeployment.Id, orgs[0].Id);
            insert destinationOrg;

            insert new Deployment_Job__c(Step__c = step.Id, Destination_Org__c = destinationOrg.Id);
        }
    }

    private static Git_Repository__c sshRepository() {
        Git_Repository__c result = new Git_Repository__c();
        result.Name = 'gitRepository';
        result.URI__c = 'git@github.com:user/repository.git';
        insert result;

        TestUtilities utility = new TestUtilities();
        utility.insertSObject(
            'Attachment',
            new Map<String, Object>{ 'Name' => 'id_rsa.pub', 'Body' => Blob.valueOf('publicKey'), 'ParentId' => result.Id }
        );
        utility.insertSObject(
            'Attachment',
            new Map<String, Object>{ 'Name' => 'id_rsa', 'Body' => Blob.valueOf('privateKey'), 'ParentId' => result.Id }
        );

        return result;
    }

    private static Git_Repository__c httpsRepository() {
        Git_Repository__c result = new Git_Repository__c();
        result.Name = 'gitRepository';
        result.URI__c = 'https://github.com/user/repository.git';
        insert result;

        Sensitive_Information__c sensitiveInformation = new Sensitive_Information__c();
        sensitiveInformation.Name = result.Id;
        sensitiveInformation.Username__c = 'username';
        sensitiveInformation.Password__c = DeployAPI.encryptApiKey('password');
        insert sensitiveInformation;

        Note note = new Note();
        note.Title = 'Extra Headers';
        note.Body = 'extraheaders';
        note.ParentId = result.Id;
        insert note;

        return result;
    }

    // INNER

    private class MdApiMock implements WebServiceMock {
        @SuppressWarnings('PMD.ExcessiveParameterList')
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType
        ) {
            response.put('response_x', createResponse());
        }

        private MetadataService.createMetadataResponse_element createResponse() {
            MetadataService.createMetadataResponse_element responseElement = new MetadataService.createMetadataResponse_element();
            MetadataService.SaveResult sr = new MetadataService.SaveResult();
            sr.success = true;

            responseElement.result = new List<MetadataService.SaveResult>{ sr };

            return responseElement;
        }
    }

    public class WebHookMock implements HttpCalloutMock {
        private Integer statusCode = 200;

        @SuppressWarnings('PMD.EmptyStatementBlock')
        public WebHookMock() {
        }

        public WebHookMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{ "isSuccess": true, "sessionId": "sessionId", "endPoint": "https://copadodev.salesforce.com/services/Soap/u/49.0/00D09000007GB3WEAW" }'
            );
            res.setStatusCode(statusCode);

            return res;
        }
    }
}