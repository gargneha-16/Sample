@IsTest
private class TestDeploymentStatusService {
    
    @IsTest
    private static void run() {
        // Setup
        Exception expectedException = null;
        
        Deployment__c automationTemplate = getDeployment();
        DeploymentStatusService.Request request = new DeploymentStatusService.Request();
        request.deploymentId = automationTemplate.Id;
                    
        CliProxy.CLIWrapper record = new CliProxy.CLIWrapper();
        record.body = JSON.serialize(request);
        
        // Exercise
        try {
            new DeploymentStatusService().getInstance().run(record);    
        }
        catch(Exception ex) {
            expectedException = ex;
        }
        
        // Verify
        System.assertEquals(null, expectedException);
    }
    
    @IsTest
    private static void runWithInvalidId() {
        // Setup
        Exception expectedException = null;
        
        DeploymentStatusService.Request request = new DeploymentStatusService.Request();
        request.deploymentId = UserInfo.getUserId();
                    
        CliProxy.CLIWrapper record = new CliProxy.CLIWrapper();
        record.body = JSON.serialize(request);
        
        // Exercise
        try {
            new DeploymentStatusService().getInstance().run(record);    
        }
        catch(Exception ex) {
            expectedException = ex;
        }
        
        // Verify
        System.assertNotEquals(null, expectedException);
    }
    
    // HELPER
    
    private static Deployment__c getDeployment(){
        return [SELECT Id, Name FROM Deployment__c LIMIT 1];
    }
    
    @TestSetup
    private static void makeData() {
        Map<String, RecordTypeInfo> deploymentRecordTypes = SObjectType.Deployment__c.getRecordTypeInfosByDeveloperName();
        TestUtilities.enableLicenses(2, 2, 2, 2, 2, 30);
        ITestDefaults userCreation = new CopadoSetupTestDefaults.UserDefaults().createRunAsUsers().executeDML();
        User standardUser = userCreation.getRunAsUsers().get('Standard')[0];
        System.runAs(standardUser) {
            TestUtilities.assignLicense(String.valueOf(standardUser.Username), true, false, false, false, false);
            
            List<Environment__c> envList = TestDataFactory.createEnvironments(2);
            
            List<Org__c> orgList = TestDataFactory.createOrgCredentials(2, standardUser.Username, envList);
            
            ITestDefaults deploymentDefaults = new CopadoUserStoryTestDefaults.DeploymentDefaults()
                .setFieldDefaults()
                .setFieldValue(
                    Deployment__c.SObjectType,
                    Deployment__c.RecordTypeId,
                    deploymentRecordTypes.get('Automation_Template').getRecordTypeId()
                )
                .setDataSize(Deployment__c.SObjectType, 1)
                .generateDefaults()
                .includeDefaults(CopadoUserStoryTestDefaults.DeploymentStepDefaults.class)
                .setFieldValue(Step__c.SObjectType, Step__c.Type__c, 'Salesforce Flow')
                .setFieldValue(Step__c.SObjectType, Step__c.DataJson__c, '{"flowApiName": "TestFlow","type":"wait","flowParameters":[]}')
                .setDataSize(Step__c.SObjectType, 10)
                .setSObjectRelation(
                    Step__c.SObjectType,
                    Deployment__c.SObjectType,
                    new Map<Schema.SObjectField, Integer>{ Step__c.Deployment__c => 1 }
                )
                .generateDefaults()
                .executeDML();
        }
    }
}