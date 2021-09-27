@isTest
private with sharing class CustomJobStepControllerTest {
    static {
        User user = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(user) {
            assignPermissions(user.Id);
        }
    }

    @testSetup
    private static void setup() {
        insertData();
    }

    @isTest
    private static void createStep() {
        // Setup

        JobTemplate__c template = jobTemplate();

        // Exercise

        JobStep__c manualStep;
        JobStep__c functionStep;
        System.runAs(user()) {
            Test.startTest();
            manualStep = CustomJobStepController.getStep(CustomJobStepController.saveStep(manualStep(template.Id)));
            functionStep = CustomJobStepController.getStep(CustomJobStepController.saveStep(functionStep(template.Id)));
            Test.stopTest();
        }

        // Verify

        System.assertEquals(1, manualStep.Order__c, 'Incorrect order assigned to manual step.');
        System.assertEquals(2, functionStep.Order__c, 'Incorrect order assigned to function step.');
    }

    @isTest
    private static void getStepOptions() {
        //Exercise

        List<CustomJobStepController.StepOption> options;
        System.runAs(user()) {
            Test.startTest();
            options = CustomJobStepController.getStepOptions();
            Test.stopTest();
        }

        // Verify

        System.assert(!options.isEmpty(), 'No step options were returned by the controller.');
    }

    @isTest
    private static void getNamespace() {
        //Exercise

        String namespace;
        System.runAs(user()) {
            Test.startTest();
            namespace = CustomJobStepController.getNamespace();
            Test.stopTest();
        }

        // Verify

        System.assertEquals(Settings.ns, namespace, 'Incorrect namespace was returned by the controller.');
    }

    // HELPER

    private static JobTemplate__c jobTemplate() {
        return [SELECT Id FROM JobTemplate__c WHERE ApiName__c = 'Copado Promote_1' LIMIT 1];
    }

    private static JobStep__c manualStep(Id parentId) {
        return new JobStep__c(
            Name = 'Manual Approval',
            Type__c = 'Manual',
            JobTemplate__c = parentId,
            ConfigJSON__c = '{"instructions":"approval","parameters":[{"name":"ownerId","value":"0052o000008q0USAAY"},{"name":"notificationType","value":"Email_Chatter"}]}'
        );
    }

    private static JobStep__c functionStep(Id parentId) {
        return new JobStep__c(
            Name = 'Echo Promote',
            Type__c = 'Function',
            JobTemplate__c = parentId,
            ConfigJSON__c = '{"functionName":"echoClone","parameters":[{"name":"my_name","value":"rafael"},{"name":"email","value":"{$User.Email}"},{"name":"sessionId","value":"{$RecordId.Credential.SessionId}"}]}'
        );
    }

    private static User user() {
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    private static void assignPermissions(Id userId) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

        for (PermissionSet permissionSet : [
            SELECT Id
            FROM PermissionSet
            WHERE
                Name IN ('Copado_User', 'Copado_Functions', 'Copado_Job_Engine')
                AND Id NOT IN (SELECT PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId = :userId)
        ]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSet.Id));
        }

        insert assignments;
    }

    private static void insertData() {
        JobTemplate__c template = new JobTemplate__c(Name = 'Copado Promote', Version__c = 1, Type__c = 'Custom');
        insert template;
    }
}