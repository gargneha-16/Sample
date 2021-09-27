public with sharing class GetStaticCodeAnalysis {
    public GetStaticCodeAnalysis() {

    }
    @AuraEnabled(cacheable=true)
    public static Static_Code_Analysis_Settings__c getStaticCodeAnalysisSettingById(Id recordId){
        Static_Code_Analysis_Settings__c staticCodeAnalysisSettings;
        try {
            List<Static_Code_Analysis_Settings__c> scaSettingsList = [
                SELECT RecordTypeId, Id, Name, Cloud_Organization__c, CodeScan_Token__c, CodeScan_URL__c, CodeScan_Version__c
                FROM Static_Code_Analysis_Settings__c
                WHERE Id = :recordId
                LIMIT 1
        ];
        if(!scaSettingsList.isEmpty()) {
            staticCodeAnalysisSettings = scaSettingsList[0];
            List<Sensitive_Information__c> sensitiveInformations = [SELECT API_Token__c FROM Sensitive_Information__c WHERE Name = :recordId];
            if(!sensitiveInformations.isEmpty()) {
                staticCodeAnalysisSettings.CodeScan_Token__c = sensitiveInformations[0].API_Token__c;
            }
        }
        return staticCodeAnalysisSettings;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static void updateStaticCodeAnalysisSetting(Static_Code_Analysis_Settings__c scaSettings){
        String TOKENMASK = '**************************';
        String sensitiveToken = scaSettings.CodeScan_Token__c;
        scaSettings.CodeScan_Token__c = TOKENMASK;
        Utilities.Secure_DML(scaSettings, Utilities.DML_Action.UPS, schema.SObjectType.Static_Code_Analysis_Settings__c);
        List<Sensitive_Information__c> sensitiveInformations = [SELECT API_Token__c FROM Sensitive_Information__c WHERE Name = :scaSettings.Id];
            if(sensitiveInformations.isEmpty()) {
                Sensitive_Information__c si = new Sensitive_Information__c(
                        Name = String.valueOf(scaSettings.Id),
                        API_Token__c = sensitiveToken);
                Utilities.Secure_DML(si, Utilities.DML_Action.INS, schema.SObjectType.Sensitive_Information__c);
            } else {
                sensitiveInformations[0].API_Token__c = sensitiveToken;
                Utilities.Secure_DML(sensitiveInformations, Utilities.DML_Action.UPD, schema.SObjectType.Sensitive_Information__c);
            }
    }

}