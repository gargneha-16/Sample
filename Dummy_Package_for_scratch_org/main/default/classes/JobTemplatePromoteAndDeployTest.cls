@SuppressWarnings('PMD')
@IsTest
private class JobTemplatePromoteAndDeployTest {
    // TODO: Remove this comment
    private static User_Story__c userStory;
    private static Deployment_Flow__c deploymentFlow;
    private static List<Environment__c> environments;
    private static JobTemplate__c deploymentJobTemplate;

    @TestSetup
    private static void setupData() {
        List<User> userList = TestDataFactory.createUsers();
        TestUtilities.enableLicenses(2, 2, 2, 2, 2);
        FeatureManagement.setPackageIntegerValue('CBM_Branches', 2);
        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name IN ('Copado_User', 'Copado_Functions', 'Copado_Job_Engine')];
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : permissionSets) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userList[0].Id, PermissionSetId = permissionSet.Id));
        }
        insert assignments;
    }

    private static testMethod void testPromoteAndDeployFromUserStorySuccess() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();
            JobStep__c jobStep = new JobStep__c();
            jobStep.Type__c = 'Manual';
            jobStep.ExecutionSequence__c = 'before';
            jobStep.UserStory__c = userStory.Id;
            insert jobStep;

            Test.startTest();
            Function.mockResponse = functionCompletionEvent(true, '', 'Sample Data');

            Test.setMock(HttpCalloutMock.class, new testHttpCalloutMock('{}', null));
            userStory.Promote_and_Deploy__c = true;
            update userStory;
            Test.getEventBus().deliver();
            Test.stopTest();

            List<Promotion__c> promotions = [SELECT Id FROM Promotion__c];
            System.assertEquals(1, promotions.size(), 'There should be only one promotion');
            List<AggregateResult> promotedUserStories = [SELECT COUNT(Id) promotedUserStoryCount FROM Promoted_User_Story__c];
            System.assertEquals(1, promotedUserStories[0].get('promotedUserStoryCount'), 'There should be only one promoted user story');

            String deployCallback = Settings.ns.replace('__', '.') + 'PromotionDeployAction';
            JobExecution__c jobExecution = [SELECT Id, ParentId__c, Callback__c, Promotion__c, Status__c, VolumeOptions__c, Template__c, DataJson__c  FROM JobExecution__c WHERE Callback__c = :deployCallback];
            
            PromotionDeployAction callback = new PromotionDeployAction();
            callback.execute(jobExecution, 'Successful');
        
            List<AggregateResult> executions = [SELECT COUNT(Id) executionCount FROM JobExecution__c];
            System.assertEquals(2, executions[0].get('executionCount'), 'There should be two execution');

            promotions.clear();
            promotions = [SELECT Id FROM Promotion__c WHERE Status__c = 'Completed'];
            System.assertEquals(1, promotions.size(), 'There is only one promotion');

            List<Deployment__c> deployments = [SELECT Id FROM Deployment__c WHERE Promotion__c IN :promotions AND Status__c = 'Completed Successfully'];
            System.assertEquals(1, deployments.size(), 'There is only one deployment');

            List<JobStep__c> executionSteps = [SELECT Id FROM JobStep__c WHERE JobExecution__r.Deployment__c = :deployments[0].Id];
            System.assertEquals(2, executionSteps.size(), 'Execution step has 2 steps');
        }
    }

    private static testMethod void testPromoteAndDeployFromUserStoryFailure() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            Test.startTest();
            Function.mockResponse = functionCompletionEvent(false, 'Error', 'Sample Data');

            Test.setMock(HttpCalloutMock.class, new testHttpCalloutMock('{}', null));
            userStory.Promote_and_Deploy__c = true;
            update userStory;
            Test.getEventBus().deliver();
            Test.stopTest();

            List<Promotion__c> promotions = [SELECT Id FROM Promotion__c WHERE Status__c = :'Completed with errors'];
            System.assertEquals(1, promotions.size(), 'There should be only one promotion');
            List<AggregateResult> promotedUserStories = [SELECT COUNT(Id) promotedUserStoryCount FROM Promoted_User_Story__c];
            System.assertEquals(1, promotedUserStories[0].get('promotedUserStoryCount'), 'There should be only one promoted user story');
            List<AggregateResult> executions = [SELECT COUNT(Id) executionCount FROM JobExecution__c];
            System.assertEquals(2, executions[0].get('executionCount'), 'There should be two execution created, one for promotion and one for deploy');
        }
    }

    private static testMethod void testPromotionValidation() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            Test.startTest();

            PageReference pReference = Page.PipelineManager;
            Test.setCurrentPage(pReference);
            ApexPages.StandardController pipelineSc = new ApexPages.StandardController(deploymentFlow);
            PipelineManagerExtension currentPipelineController = new PipelineManagerExtension(pipelineSc);
            currentPipelineController.populateFlowGridMap();
            currentPipelineController.getPromotableUserStoriesCount();
            currentPipelineController.getBackPromotableUserStoriesCount();

            List<PipelineManagerExtension.EnvironmentWrapper> assertionStage = new List<PipelineManagerExtension.EnvironmentWrapper>(
                currentPipelineController.allEnvironmentsByStageGroupMap.get('Stage 1').get(environments[2].Id)
            );
            System.assertEquals(2, assertionStage.size(), 'The number of environments in stage 1 is not 2');
            System.assertEquals(false, assertionStage[0].isDestinationEnv, 'Environment 1 in stage 1 is not marked as Destination Environment');
            System.assertEquals(1, assertionStage[0].userStoriesAhead, 'In Environment 2 there are not only 1 User Stories Ahead in stage 1');
            System.assertEquals(0, assertionStage[0].userStoriesBehind, 'In Environment 2 there are more than 0 User Stories Behind in stage 1');

            System.assertEquals(false, assertionStage[1].isDestinationEnv, 'Environment 2 in stage 1 is not marked as Destination Environment');
            System.assertEquals(0, assertionStage[1].userStoriesAhead, 'In Environment 2 there are not only 0 User Stories Ahead in stage 1');
            System.assertEquals(0, assertionStage[1].userStoriesBehind, 'In Environment 2 there are more than 0 User Stories Behind in stage 1');

            // This code block simulates a click on a forward arrow in Pipeline Manager
            ApexPages.currentPage().getParameters().put('fromId', environments[0].Id);
            ApexPages.currentPage().getParameters().put('toId', environments[2].Id);
            ApexPages.currentPage().getParameters().put('pathType', 'merge');
            currentPipelineController.getPromotableBackPromotableUserStoriesList();
            // End of code block

            System.assertEquals('merge', currentPipelineController.newOverlay.pathType, 'Path type is not merge');
            System.assertEquals(1, currentPipelineController.newOverlay.userStories.size(), 'Number of user stories is not 1');

            currentPipelineController.createPromotionforValidation();

            Test.stopTest();
        }
    }

    private static testMethod void testPromotionCreationAndDeploy() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            deploymentFlow = [SELECT  Id, OwnerId, IsDeleted, Name, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastViewedDate, LastReferencedDate, Active__c, Branch_Management_Coordinates__c, Disable_Validations__c, Equal_Branch_Environment_Name__c, Flow_Step_Coordinates__c, Git_Repository__c, Main_Branch__c, Manage_Branches__c, Static_Code_Analysis_Settings__c, Block_Commits__c, Calculate_Based_on__c, Copado_DX_Mode__c, Enable_Copado_DX__c, Exclude_From_Auto_Resolve__c, Hide_Tabs__c, Order_by__c, Merge_Strategy__c, Enable_Smart_Conflict_Resolution__c, Promotion_Automation__c, Deployment_Automation__c, Platform__c, Promotion_Job_Template__c, Deployment_Job_Template__c, Promotion_Job_Template__r.ApiName__c, Deployment_Job_Template__r.ApiName__c FROM Deployment_Flow__c WHERE Id = :deploymentFlow.Id][0];

            PageReference pReference = Page.PipelineManager;
            Test.setCurrentPage(pReference);
            ApexPages.StandardController pipelineSc = new ApexPages.StandardController(deploymentFlow);
            PipelineManagerExtension currentPipelineController = new PipelineManagerExtension(pipelineSc);
            currentPipelineController.populateFlowGridMap();
            currentPipelineController.getPromotableUserStoriesCount();
            currentPipelineController.getBackPromotableUserStoriesCount();

            // This code block simulates a click on a forward arrow in Pipeline Manager
            ApexPages.currentPage().getParameters().put('fromId', environments[0].Id);
            ApexPages.currentPage().getParameters().put('toId', environments[2].Id);
            ApexPages.currentPage().getParameters().put('pathType', 'merge');
            currentPipelineController.getPromotableBackPromotableUserStoriesList();
            // End of code Block

            Test.startTest();
            currentPipelineController.createPromotion();

            // Assertions
            Promotion__c currentPromotionWrapper = currentPipelineController.promotionWrappers[0].promotion; // Created for better readability
            
            Promotion__c assertCurrentPromotion = [
                SELECT Id, Name, Destination_Environment__c, Source_Environment__c, Project__c, Status__c
                FROM Promotion__c
                WHERE Source_Environment__r.Name = :environments[0].Name AND Destination_Environment__r.Name = :environments[2].Name
                LIMIT 1
            ];

            System.assertNotEquals(null, assertCurrentPromotion.Id, 'Promotion is not created');
            System.assertEquals(
                1,
                currentPipelineController.promotionWrappers.size(),
                'Promotion list wrapper is not populated correctly with 1 record'
            );
            System.assertEquals(
                assertCurrentPromotion.Name,
                currentPromotionWrapper.Name,
                'Name of Promotion created and Promotion shown in the list is not the same'
            );
            System.assertEquals(
                assertCurrentPromotion.Destination_Environment__c,
                currentPromotionWrapper.Destination_Environment__c,
                'Destination Environment of Promotion created and Promotion shown in the list is not the same'
            );
            System.assertEquals(
                assertCurrentPromotion.Source_Environment__c,
                currentPromotionWrapper.Source_Environment__c,
                'Source Environment of Promotion created and Promotion shown in the list is not the same'
            );
            System.assertEquals(
                assertCurrentPromotion.Project__c,
                currentPromotionWrapper.Project__c,
                'Project of Promotion created and Promotion shown in the list is not the same'
            );
            System.assertEquals('Draft', currentPromotionWrapper.Status__c, 'Draft of Promotion shown in the list is not Scheduled');
            System.assertEquals(
                assertCurrentPromotion.Status__c,
                currentPromotionWrapper.Status__c,
                'Name of Promotion created and Promotion shown in the list is not the same'
            );

            
            Function.mockResponse = functionCompletionEvent(true, '', 'Sample Data');
            currentPipelineController.deploySelectedPromotions();
            Test.getEventBus().deliver();
            Test.stopTest();

            List<AggregateResult> executions = [SELECT COUNT(Id) executionCount FROM JobExecution__c];
            System.assertEquals(2, executions[0].get('executionCount'), 'There should be two execution, one for promote and one for deploy');
        }
    }

    private static testMethod void testPromotionPromoteAndDeploy() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            data();

            deploymentFlow = [SELECT  Id, OwnerId, IsDeleted, Name, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastViewedDate, LastReferencedDate, Active__c, Branch_Management_Coordinates__c, Disable_Validations__c, Equal_Branch_Environment_Name__c, Flow_Step_Coordinates__c, Git_Repository__c, Main_Branch__c, Manage_Branches__c, Static_Code_Analysis_Settings__c, Block_Commits__c, Calculate_Based_on__c, Copado_DX_Mode__c, Enable_Copado_DX__c, Exclude_From_Auto_Resolve__c, Hide_Tabs__c, Order_by__c, Merge_Strategy__c, Enable_Smart_Conflict_Resolution__c, Promotion_Automation__c, Deployment_Automation__c, Platform__c, Promotion_Job_Template__c, Deployment_Job_Template__c, Promotion_Job_Template__r.ApiName__c, Deployment_Job_Template__r.ApiName__c FROM Deployment_Flow__c WHERE Id = :deploymentFlow.Id][0];

            PageReference pReference = Page.PipelineManager;
            Test.setCurrentPage(pReference);
            ApexPages.StandardController pipelineSc = new ApexPages.StandardController(deploymentFlow);
            PipelineManagerExtension currentPipelineController = new PipelineManagerExtension(pipelineSc);
            currentPipelineController.populateFlowGridMap();
            currentPipelineController.getPromotableUserStoriesCount();
            currentPipelineController.getBackPromotableUserStoriesCount();

            // This code block simulates a click on a forward arrow in Pipeline Manager
            ApexPages.currentPage().getParameters().put('fromId', environments[0].Id);
            ApexPages.currentPage().getParameters().put('toId', environments[2].Id);
            ApexPages.currentPage().getParameters().put('pathType', 'merge');
            currentPipelineController.getPromotableBackPromotableUserStoriesList();
            // End of code Block

            Test.startTest();
            Function.mockResponse = functionCompletionEvent(true, '', 'Sample Data');
            currentPipelineController.createPromotionListAndDeploy();
            Test.getEventBus().deliver();
            Test.stopTest();


            // Assertions

            List<Promotion__c> promotions = [SELECT Id FROM Promotion__c];
            System.assertEquals(1, promotions.size(), 'There should be only one promotion');
            List<AggregateResult> promotedUserStories = [SELECT COUNT(Id) promotedUserStoryCount FROM Promoted_User_Story__c];
            System.assertEquals(1, promotedUserStories[0].get('promotedUserStoryCount'), 'There should be only one promoted user story');

            String deployCallback = Settings.ns.replace('__', '.') + 'PromotionDeployAction';
            JobExecution__c jobExecution = [SELECT Id, ParentId__c, Callback__c, Promotion__c, Status__c, VolumeOptions__c, Template__c, DataJson__c  FROM JobExecution__c WHERE Callback__c = :deployCallback];
            
            PromotionDeployAction callback = new PromotionDeployAction();
            callback.execute(jobExecution, 'Successful');
        
            List<AggregateResult> executions = [SELECT COUNT(Id) executionCount FROM JobExecution__c];
            System.assertEquals(2, executions[0].get('executionCount'), 'There should be two execution');

            promotions.clear();
            promotions = [SELECT Id FROM Promotion__c WHERE Status__c = 'Completed'];
            System.assertEquals(1, promotions.size(), 'There is only one promotion');

            List<Deployment__c> deployments = [SELECT Id FROM Deployment__c WHERE Promotion__c IN :promotions AND Status__c = 'Completed Successfully'];
            System.assertEquals(1, deployments.size(), 'There is only one deployment');
        }
    }

    private static void data() {
        Personal_Settings__c ps = Personal_Settings__c.getInstance();
        if (String.isBlank(ps.API_Key__c)) {
            ps.API_Key__c = DeployAPI.encryptAPIKey('99999999999999999999');
            upsert ps;
        }

        //Environment creation
        environments = new List<Environment__c>();
        for (Integer i = 0; i < 3; i++) {
            Environment__c environment = TestDataFactory.createEnvironments('Environment ' + i, 'Production/Developer');
            environment.Platform__c = 'Other';
            environments.add(environment);
        }
        insert environments;

        // Function creation
        String namespace = namespacePrefix();
        Function__c functionPromotion = new Function__c(
            Name = 'mulePromotion',
            API_Name__c = 'mulePromotion',
            Script__c = 'echo hello world $par1',
            Type__c = 'Custom',
            Parameters__c = '[{"name": "SourceDBName", "defaultValue": "{!$Source.Property.DBName}", "required": true},' +
                '{"name": "DestinationDBProvider", "defaultValue": "{!$Destination.Property.DB-Provider}", "required": true},' +
                '{"name": "PipelineUsername", "defaultValue": "{!$Pipeline.Property.Username}", "required": true},' +
                '{"name": "UserEmail", "defaultValue": "{!$User.Property.Email}", "required": true},' +
                '{"name": "LogLevel", "defaultValue": "ERROR", "required": false}]',
            Options__c = '[{"name": "gitUrl", "value": "xxxxxx", "sensitive": true},' +
                '{"name": "gitUsername", "value": "", "sensitive": true},' +
                '{"name": "gitPassword", "value": "", "sensitive": true},' +
                '{"name": "branchName", "value": "", "sensitive": false}]',
            Callback_Type__c = 'ApexClass',
            ApexClass__c = namespace + 'FunctionStepExecutionCallback'
        );
        Function__c functionDeployment = new Function__c(
            Name = 'muleDeployment',
            API_Name__c = 'muleDeployment',
            Script__c = 'echo hello world $par1',
            Type__c = 'Custom',
            Parameters__c = '[{"name": "SourceDBName", "defaultValue": "{!$Source.Property.DBName}", "required": true},' +
                '{"name": "DestinationDBProvider", "defaultValue": "{!$Destination.Property.DB-Provider}", "required": true},' +
                '{"name": "PipelineUsername", "defaultValue": "{!$Pipeline.Property.Username}", "required": true},' +
                '{"name": "UserEmail", "defaultValue": "{!$User.Property.Email}", "required": true},' +
                '{"name": "LogLevel", "defaultValue": "ERROR", "required": false}]',
            Options__c = '[{"name": "gitUrl", "value": "xxxxxx", "sensitive": true},' +
                '{"name": "gitUsername", "value": "", "sensitive": true},' +
                '{"name": "gitPassword", "value": "", "sensitive": true},' +
                '{"name": "branchName", "value": "", "sensitive": false}]',
            Callback_Type__c = 'ApexClass',
            ApexClass__c = namespace + 'FunctionStepExecutionCallback'
        );
        insert new List<Function__c>{ functionPromotion, functionDeployment };

        // Job template creation
        deploymentJobTemplate = TestDataFactory.createJobTemplate('JOB_TEMPLATE_DEPLOYMENT', 'JOB_TEMPLATE_DEPLOYMENT', 1, '[{ "name": "volumeEnabled", "value": "true" }]');
        JobTemplate__c promotionJobTemplate = TestDataFactory.createJobTemplate('JOB_TEMPLATE_PROMOTION', 'JOB_TEMPLATE_PROMOTION', 1, '[{ "name": "volumeEnabled", "value": "true" }]');
        insert new List<JobTemplate__c>{ deploymentJobTemplate, promotionJobTemplate };

        // Job step creation
        JobStep__c functionDeploymentStep = TestDataFactory.createJobStep(
            'Function',
            deploymentJobTemplate.Id,
            'Function',
            1,
            '{"functionName":"muleDeployment","parameters":[]}'
        );
        JobStep__c functionPromotionStep = TestDataFactory.createJobStep(
            'Function',
            promotionJobTemplate.Id,
            'Function',
            1,
            '{"functionName":"mulePromotion","parameters":[]}'
        );
        insert new List<JobStep__c>{ functionDeploymentStep, functionPromotionStep };

        // Git repository creation
        Git_Repository__c gitRepository = TestDataFactory.createGitRepository();
        insert gitRepository;

        // Deployment flow creation
        deploymentFlow = TestDataFactory.createDeploymentFlow('Deployment Flow', true, gitRepository.Id, false);
        deploymentFlow.Main_Branch__c = 'master';
        deploymentFlow.Platform__c = 'Other';
        deploymentFlow.Promotion_Job_Template__c = promotionJobTemplate.Id;
        deploymentFlow.Deployment_Job_Template__c = deploymentJobTemplate.Id;
        insert deploymentFlow;

        // Deployment flow steps creation
        Deployment_Flow_Step__c deploymentFlowStep1 = TestDataFactory.createDeploymentFlowStep(
            environments[0].Id,
            environments[2].Id,
            deploymentFlow.Id,
            ''
        );
        deploymentFlowStep1.Branch__c = 'dev1';
        Deployment_Flow_Step__c deploymentFlowStep2 = TestDataFactory.createDeploymentFlowStep(
            environments[1].Id,
            environments[2].Id,
            deploymentFlow.Id,
            ''
        );
        deploymentFlowStep1.Branch__c = 'dev2';
        insert new List<Deployment_Flow_Step__c>{ deploymentFlowStep1, deploymentFlowStep2 };

        // Org Credential creation
        List<Org__c> credentials = [
            SELECT Id, Name, Environment__c, Platform__c, Oauth_Signature__c, Validated_Date__c, Disable_Validation__c, SFDC_Org_ID__c
            FROM Org__c
            WHERE Platform__c = 'Other'
        ];
        for (Org__c org : credentials) {
            org.Username__c = UserInfo.getUserName();
            org.SFDC_Org_ID__c = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();
            org.Oauth_Signature__c = org.Name;
            org.Validated_Date__c = System.now();
            org.Disable_Validation__c = true;
            break;
        }
        update credentials;

        // Project creation
        Project__c project = TestDataFactory.createProject('My project', deploymentFlow.Id, false);
        insert project;

        // User Story creation
        userStory = TestDataFactory.createUserStory('us-0000000', 'Approved', null, project.Id, null, credentials[0].Id);
        userStory.Promote_Change__c = true;
        insert userStory;
    }

    private static String namespacePrefix() {
        return Settings.ns.replace('__', '.');
    }

    private static MC_Result__e functionCompletionEvent(Boolean isSuccess, String errorMessage, String data) {
        MC_Result__e result = new MC_Result__e();
        result.IsFinished__c = true;
        result.Result_Data__c = data;
        result.IsSuccess__c = isSuccess;
        result.Error_Message__c = errorMessage;

        return result;
    }
}