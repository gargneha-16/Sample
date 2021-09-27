@IsTest
private class TestOrgTrigger {
    @TestSetup
    private static void setupData() {
        List<User> userList = TestDataFactory.createUsers();
        TestUtilities.enableLicenses(2, 2, 2, 2, 2);
        FeatureManagement.setPackageIntegerValue('CBM_Branches', 2);
        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name IN ('Copado_User', 'Copado_Functions')];
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : permissionSets) {
            assignments.add(new PermissionSetAssignment(AssigneeId = userList[0].Id, PermissionSetId = permissionSet.Id));
        }
        insert assignments;
    }
    private static testMethod void test_OrgTrigger() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            BatchHelper.enforceScheduler();
            CronJobDetail cjd = [SELECT Id FROM CronJobDetail WHERE Name = 'Copado' AND JobType = '7' LIMIT 1];
            if (BatchHelper.isCopadoScheduled()) {
                System.abortJob([SELECT Id FROM CronTrigger WHERE CronJobDetailId = :cjd.Id LIMIT 1].Id);
            }
            System.assertEquals(false, BatchHelper.isCopadoScheduled());

            Org__c testOrg = testMethodUtilities.createOrg('OrgName2', 'Sandbox', 'SFDC_OrgId2', 'SFDC_TOKEN', 'USERNAME', System.now());
            testOrg.Test_Frequency__c = 'Daily';
            insert testOrg;

            System.assertEquals(true, BatchHelper.isCopadoScheduled());
        }
    }
    private static testMethod void test_environmentCreation() {
        User sysUser = [SELECT Id, Name, LastName, Email, Username FROM User WHERE Email = 'test1@test1.com' LIMIT 1];
        TestUtilities.assignLicense(String.valueOf(sysUser.Username), true, true, true, true, true);

        System.runAs(sysUser) {
            // Org Credential creation
            List<Org__c> credentials = TestDataFactory.createOrgCredentials(1, sysUser.Username);

            //Environment creation
            List<Environment__c> environments = TestDataFactory.createEnvironments(1);

            for (Environment__c environment : environments) {
                environment.Org_ID__c = UserInfo.getOrganizationId();
            }
            update environments;

            for (integer i = 0; i < credentials.size(); i++) {
                credentials[i].Username__c = UserInfo.getUserName();
                credentials[i].SFDC_Org_ID__c = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();
                credentials[i].Oauth_Signature__c = credentials[i].Name;
                credentials[i].Validated_Date__c = System.now();
                credentials[i].Disable_Validation__c = true;
            }
            update credentials;

            List<Environment__c> expectedEnvironments = [
                SELECT Id, Name, Org_ID__c
                FROM Environment__c
                WHERE Org_ID__c = :UserInfo.getOrganizationId()
            ];
            System.assertEquals(1, expectedEnvironments.size());
            List<Org__c> expectedCredentials = [SELECT Id, Environment__c, SFDC_Org_ID__c FROM Org__c];
            System.assertEquals(expectedEnvironments[0].Id, expectedCredentials[0].Environment__c);
        }
    }
}