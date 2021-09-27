@IsTest
private class TestAutomationTemplateUpgrade {
	@IsTest
    private static void run() {
        // Setup
        Deployment__c automationTemplate = getDeployment();
        insert new Automation_Template_For_CLI__c(Name = automationTemplate.Name, Automation_Template_Name__c = automationTemplate.ApiName__c);

        // Exercise
         String serializedResponse = new AutomationTemplateUpgrade().getInstance().run(new CliProxy.CLIWrapper());
        
        // Verify
    	AutomationTemplateUpgrade.Response response = (AutomationTemplateUpgrade.Response) JSON.deserialize(serializedResponse, 
                                                                                                            AutomationTemplateUpgrade.Response.class);
        
        System.assertEquals('OK', response.status);
    }
    
    // HELPER

    private static Deployment__c getDeployment(){
        return [SELECT Id, Name, ApiName__c FROM Deployment__c LIMIT 1];
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
                .setFieldValue(Deployment__c.SObjectType, Deployment__c.ApiName__c, 'Deployment')
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