public without sharing class OrgTriggerHelper {
    private static Boolean sched = false;
    private static String[] idsToRemoveAttach = new List<String>{};
    private static Map<String, Environment__c> environmentsBySFDCOrgIds;
    public static List<Environment__c> environments;

    public static void prepareData(List<SObject> records) {
        environments = new List<Environment__c>();
        environmentsBySFDCOrgIds = new Map<String, Environment__c>();
        Set<String> orgIds = new Set<String>();

        for (SObject so : records) {
            Org__c credentialRecord = (Org__c) so;
            String sfdcOrgId = extractOrgId((String) credentialRecord.SFDC_Org_ID__c);
            Boolean isSalesforceCredential = credentialRecord.Platform__c == null || credentialRecord.Platform__c == 'Salesforce';
            if (isSalesforceCredential && sfdcOrgId != null) {
                orgIds.add(sfdcOrgId);
            }
        }
        if (!orgIds.isEmpty()) {
            populateEnvionmentMap(orgIds);

            for (SObject so : records) {
                Org__c neworg = (Org__c) so;
                String sfdcorgId = extractOrgId((String) neworg.SFDC_Org_ID__c);
                Environment__c newEnvironment = environmentsBySFDCOrgIds.get(sfdcorgId);
                if (!environmentsBySFDCOrgIds.containsKey(sfdcorgId)) {
                    newEnvironment = new Environment__c();
                    newEnvironment.Name = neworg.Name;
                    newEnvironment.Type__c = neworg.Org_Type__c;
                    newEnvironment.Org_ID__c = sfdcorgId;
                    newEnvironment.Platform__c = 'Salesforce';
                    environments.add(newEnvironment);
                }
            }
            upsert environments;

            populateEnvionmentMap(orgIds);
        }
    }
    private static void populateEnvionmentMap(Set<String> orgIds) {
        for (Environment__c environmentRecord : [SELECT Id, Name, Org_ID__c FROM Environment__c WHERE Org_ID__c IN :orgIds]) {
            environmentsBySFDCOrgIds.put(environmentRecord.Org_ID__c, environmentRecord);
        }
    }
    public static Boolean isScheduled(Org__c credentialRecord) {
        if (
            credentialRecord.Test_Frequency__c != null &&
            credentialRecord.Test_Frequency__c != 'None' &&
            credentialRecord.Validated_Date__c != null
        ) {
            sched = true;
            return true;
        }
        return false;
    }
    public static void checkApexTest(Org__c credentialRecord) {
        if (isScheduled(credentialRecord) && !FeatureHelper.isFeatureEnabled('Apex Test')) {
            credentialRecord.Test_Frequency__c = 'None';
        }
    }
    public static void enforceScheduler() {
        if (sched)
            BatchHelper.enforceScheduler();
    }
    public static void isMetadataChanged(Org__c credentialRecord, Org__c oldcredentialRecord) {
        if (oldcredentialRecord.Metadata_Types__c != credentialRecord.Metadata_Types__c) {
            idsToRemoveAttach.add(credentialRecord.Id);
        }
    }
    public static void deleteMetadataAttachments() {
        Utilities.Secure_DML(
            [SELECT Id FROM Attachment WHERE ParentId = :idsToRemoveAttach AND Name = 'MetaData'],
            Utilities.DML_Action.DEL,
            schema.SObjectType.Attachment
        );
    }
    public static void setOrgEnvironment(Org__c newCredentialRecord) {
        String newId = extractOrgId(newCredentialRecord.SFDC_Org_ID__c);
        Boolean isSalesforceCredential = newCredentialRecord.Platform__c == null || newCredentialRecord.Platform__c == 'Salesforce';
        if (isSalesforceCredential && newId != null && environmentsBySFDCOrgIds.containsKey(newId)) {
            newCredentialRecord.Environment__c = environmentsBySFDCOrgIds.get(newId).Id;
        }
    }
    private static String extractOrgId(String sfdxOrgId) {
        if (sfdxOrgId == null) {
            return null;
        }
        if (sfdxOrgId.length() >= 37 && sfdxOrgId.contains('_')) {
            return sfdxOrgId.split('_')[0];
        }
        if (sfdxOrgId.length() == 18 && sfdxOrgId.startsWith('00D')) {
            return sfdxOrgId;
        }
        return null;
    }
    private static Boolean isValidCopadoSFDC_Org_Id(String credentialId) {
        return String.isNotBlank(credentialId) && credentialId.length() >= 37;
    }
    private static String getBaseSFDC_Org_Id(String credentialId) {
        if (!isValidCopadoSFDC_Org_Id(credentialId)) {
            return credentialId;
        }
        return credentialId.substring(0, 37);
    }
}