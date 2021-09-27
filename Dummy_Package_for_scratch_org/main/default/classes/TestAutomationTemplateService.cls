@IsTest
private class TestAutomationTemplateService {
    
    private static final String STANDARD_USER = 'test_user@myorg.com';
    
    @IsTest
    private static void run() {
        
        System.runAs(getStandardUser()) {
            // Setup
            Deployment__c automationTemplate = getDeployment();
            AutomationTemplateService.Request request = new AutomationTemplateService.Request();
            request.templateId = automationTemplate.Id;
            
            CliProxy.CLIWrapper record = new CliProxy.CLIWrapper();
            record.body = JSON.serialize(request);
            
            // Exercise
            new AutomationTemplateService().run(record);
            
            // Verify
            List<Deployment__c> convertedDeployments = getConvertedDeployments(automationTemplate);
            List<Result__c> results = getResults(convertedDeployments[0]);
            System.assertEquals(1, convertedDeployments.size(), 'The automation template should be converted in a new advanced deployment record');
            System.assertEquals(1, results.size(), 'There should be only one result record for this deployment record');
        }
    }
    
    
    @IsTest
    private static void runWithInvalidStepJson() {
        
        System.runAs(getStandardUser()) {
            // Setup
			Exception expectedException = null;
            
            Deployment__c automationTemplate = getDeployment();
            AutomationTemplateService.Request request = new AutomationTemplateService.Request();
            request.templateId = automationTemplate.Id;
            request.stepJsonById = new Map<Id, String> {
            	automationTemplate.Id => 'Invalid json'
            };
                
            CliProxy.CLIWrapper record = new CliProxy.CLIWrapper();
            record.body = JSON.serialize(request);
            
            // Exercise
            try {
                new AutomationTemplateService().getInstance().run(record);    
            }
            catch(Exception ex) {
                expectedException = ex;
            }
            
            // Verify
            System.assertNotEquals(null, expectedException);
        }
    }
    
    // HELPER
    
    private static User getStandardUser(){
        return [SELECT Username FROM User WHERE Username = :STANDARD_USER LIMIT 1];
    }

    private static Deployment__c getDeployment(){
        return [SELECT Id, Name FROM Deployment__c LIMIT 1];
    }

    private static List<Org__c> getOrgs(){
        return [SELECT Id FROM Org__c];
    }

    private static List<Deployment__c> getConvertedDeployments(Deployment__c automationTemplate){
        String newDeploymentName = Label.Execution_of + ' ' + automationTemplate.Name;
        return [SELECT Id FROM Deployment__c WHERE Name = :newDeploymentName];
    }

    private static List<Result__c> getResults(Deployment__c automationTemplate){
        return [SELECT Id FROM Result__c WHERE Deployment__c = :automationTemplate.Id];
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