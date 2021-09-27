@IsTest
private class ValidatePlatformTypeTest {
    
    @IsTest
    private static void updateEnvironmentPlatformToSameType() {

        // Setup
        Exception expectedException = null;
        Deployment_Flow__c pipeline = createPipeline();
        Environment__c environment = createEnvironment();
        Deployment_Flow_Step__c connection = createConnection(pipeline.Id, environment.Id);

        
        // Exercise
        try {
            environment.Platform__c = 'Salesforce';
            update environment;
        }
        catch(Exception ex) {
            expectedException = ex;
        }


        // Verify
        System.assertEquals(null, expectedException);
    }
    
    
    @IsTest
    private static void updateEnvironmentPlatformToDifferentType() {

        // Setup
        Exception expectedException = null;
        Deployment_Flow__c pipeline = createPipeline();
        Environment__c environment = createEnvironment();
        Deployment_Flow_Step__c connection = createConnection(pipeline.Id, environment.Id);
        
        
        // Exercise
        try {
            environment.Platform__c = 'Other';
            update environment;
        }
        catch(Exception ex) {
            expectedException = ex;
        }


        // Verify
        System.assertNotEquals(null, expectedException);
    }
    
    
    @IsTest
    private static void updatePipelinePlatformToDifferentType() {

        // Setup
        Exception expectedException = null;
        Deployment_Flow__c pipeline = createPipeline();
        Environment__c environment = createEnvironment();
        Deployment_Flow_Step__c connection = createConnection(pipeline.Id, environment.Id);
        
        
        // Exercise
        try {
            pipeline.Platform__c = 'Other';
            update pipeline;
        }
        catch(Exception ex) {
            expectedException = ex;
        }


        // Verify
        System.assertNotEquals(null, expectedException);
    }
    
    
    // Helper
    
    private static Deployment_Flow__c createPipeline() {
        Deployment_Flow__c result = new Deployment_Flow__c();
        result.Platform__c = 'Salesforce';
        insert result;
        
        return result;
    }
    
        
    private static Environment__c createEnvironment() {
        Environment__c result = new Environment__c();
        result.Platform__c = 'Salesforce';
        insert result;
        
        return result;
    }
    
    
    private static Deployment_Flow_Step__c createConnection(Id pipelineId, Id environmentId) {
        Deployment_Flow_Step__c result = new Deployment_Flow_Step__c();
        result.Deployment_Flow__c = pipelineId;
        result.Source_Environment__c = environmentId;
        result.Destination_Environment__c = environmentId;
        insert result;
        
        return result;
    }
}