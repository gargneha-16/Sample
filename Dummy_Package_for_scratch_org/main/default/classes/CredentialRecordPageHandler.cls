public with sharing class CredentialRecordPageHandler {
    private static List<ValidationResult> validationResults { get; set; }

    private static final String ACTION_INFO = 'action:info';
    private static final String ACTION_CLOSE = 'action:close';
    private static final String ACTION_APPROVAL = 'action:approval';

    @AuraEnabled
    public static String getMetadataTypesFieldHelpText() {
        return Org__c.Metadata_Types__c.getDescribe().getInlineHelpText();
    }

    @AuraEnabled
    public static List<ValidationResult> validateOrgAndReturnResultWrapper(String credentialId) {
        validationResults = new List<ValidationResult>();
        if (String.isNotBlank(credentialId)) {
            Org__c credential = [
                SELECT Id, Org_Type__c, Test_Frequency__c, Disable_Validation__c, Oauth_Signature__c, Platform__c
                FROM Org__c
                WHERE Id = :credentialId
            ];
            if (credential.Platform__c != null && credential.Platform__c != 'Salesforce') {
                createValidationResultRecordAndAddToList(ACTION_INFO, Label.Non_Salesforce_Credential);
                populateKeyNumberOfValidationResult();
                return validationResults;
            }

            Boolean isScratchOrg = String.isNotBlank(credential.Org_Type__c) && credential.Org_Type__c.startsWithIgnoreCase('Scratch Org');
            if (credential.Id != null && !credential.Disable_Validation__c && !isScratchOrg) {
                if (credential.Oauth_Signature__c == null) {
                    createValidationResultRecordAndAddToList(ACTION_INFO, Label.ADD_AUTHENTICATION);
                    populateKeyNumberOfValidationResult();
                    return validationResults;
                } else {
                    if (!DeployAPI.validateOrg(credential.Id)) {
                        createValidationResultRecordAndAddToList(ACTION_CLOSE, Label.WRONG_CREDENTIALS);
                        populateKeyNumberOfValidationResult();
                        return validationResults;
                    } else {
                        createValidationResultRecordAndAddToList(ACTION_APPROVAL, Label.OK_CREDENTIALS);
                    }
                }
                if (credential.Test_Frequency__c != null && credential.Test_Frequency__c != 'None') {
                    Org__c copadoOrg = DeployAPI.getCustomerOrg();
                    if (copadoOrg == null) {
                        createValidationResultRecordAndAddToList(ACTION_CLOSE, Label.CUSTOMER_ORG_NOT_EXISTS);
                        populateKeyNumberOfValidationResult();
                        return validationResults;
                    }
                    if (!DeployAPI.validateOrg(copadoOrg.Id)) {
                        createValidationResultRecordAndAddToList(ACTION_CLOSE, Label.CUSTOMER_ORG_NOT_VALIDATED);
                    }
                }
            }
        }
        populateKeyNumberOfValidationResult();
        return validationResults;
    }

    private static void createValidationResultRecordAndAddToList(String iconName, String message) {
        ValidationResult validationResultItem = new ValidationResult();
        validationResultItem.iconName = iconName;
        validationResultItem.message = message;
        validationResults.add(validationResultItem);
    }

    private static void populateKeyNumberOfValidationResult() {
        for (integer i = 0; i < validationResults.size(); i++) {
            validationResults[i].keyNumber = i;
        }
    }

    @AuraEnabled
    public static List<String> getMetadataTypesForGivenCredentialId(String credentialId) {
        return MetadataTypesHelper.getMetadataTypesByOrgId(credentialId);
    }

    public with sharing class ValidationResult {
        @AuraEnabled
        public Integer keyNumber;
        @AuraEnabled
        public String iconName;
        @AuraEnabled
        public String message;
    }
}