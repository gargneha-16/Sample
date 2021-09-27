public with sharing class AuthGrantService implements CLIInterface {
    /**
     * Empty constructor is necessary to initalise the interface impl.
     */
    public AuthGrantService() {
    }
    /**
     * Get instance of AuthGrantService that implements CLI Interface
     * @return instance of AuthGrantService()
     */
    public CLIInterface getInstance() {
        return new AuthGrantService();
    }

    /**
     * Runs requested operation under root service
     * @see CliSfDataWrapper
     * @see CliSfDataWrapper.ReturnWrapper returned information details
     * @return JSON of CliSfDataWrapper.ReturnWrapper for CLI communication
     */
    public String run(CliProxy.CLIWrapper record) {
        String securityException = securityCheck();
        if (String.isNotBlank(securityException)) {
            return securityException;
        }
        String statusResult = CliSfDataWrapper.StatusResult.OK.name();
        String messageResult = 'ScratchOrg Credential created';
        String environmentId;
        String scratchOrgId;

        AuthGrantWrapper newCopadoScratchOrgInfo;
        try {
            newCopadoScratchOrgInfo = (AuthGrantWrapper) JSON.deserialize(record.body, AuthGrantWrapper.class);
        } catch (Exception ex) {
            return CliSfDataWrapper.jsonReturnResult(CliSfDataWrapper.StatusResult.ERROR.name(), ex.getMessage());
        }
        environmentId = getEnvironment(newCopadoScratchOrgInfo.scratchOrgId);
        List<Org__c> devHubCopado = getDevHubCopado(newCopadoScratchOrgInfo);
        String scratchOrgInfoCheck = checkScrathcOrgInfo(devHubCopado, newCopadoScratchOrgInfo);
        if (String.isNotBlank(scratchOrgInfoCheck)) {
            return CliSfDataWrapper.jsonReturnResult(CliSfDataWrapper.StatusResult.ERROR.name(), scratchOrgInfoCheck);
        }

        Savepoint sp;
        try {
            if (!Test.isRunningTest()) {
                sp = Database.setSavepoint();
            }
            if (String.isBlank(environmentId)) {
                Environment__c newScratchOrgEnvironment = new Environment__c();
                newScratchOrgEnvironment.Name = newCopadoScratchOrgInfo.environmentName;
                newScratchOrgEnvironment.Org_ID__c = newCopadoScratchOrgInfo.scratchOrgId;
                newScratchOrgEnvironment.Type__c = 'Scratch Org';
                environmentId = ((Environment__c) Utilities.Secure_DML(
                        newScratchOrgEnvironment,
                        Utilities.DML_Action.INS,
                        Schema.SObjectType.Environment__c
                    ))
                    .Id;
            }

            Org__c newCopadoScratchOrg = new Org__c();
            newCopadoScratchOrg.Environment__c = environmentId;
            newCopadoScratchOrg.Name = newCopadoScratchOrgInfo.environmentName;
            newCopadoScratchOrg.Username__c = newCopadoScratchOrgInfo.scratchOrgUserName;
            newCopadoScratchOrg.Org_Type__c = 'Scratch Org';
            newCopadoScratchOrg.Developer_Hub_Org__c = devHubCopado[0].Id;
            newCopadoScratchOrg.Scratch_Org_Status__c = 'Active';
            newCopadoScratchOrg.Validated_Date__c = System.now(); 
            // comment to be deleted 
            newCopadoScratchOrg.Scratch_Org_Expiration_Date__c = Date.valueOf(newCopadoScratchOrgInfo.scratchOrgExpirationDate);
            newCopadoScratchOrg.SFDC_Org_ID__c = newCopadoScratchOrgInfo.scratchOrgId + '_' + UserInfo.getUserId();
            scratchOrgId = ((Org__c) Utilities.Secure_DML(newCopadoScratchOrg, Utilities.DML_Action.INS, Schema.SObjectType.Org__c)).Id;

            Attachment authInfoAttachment = new Attachment();
            authInfoAttachment.Name = 'ScratchOrgExternal';
            authInfoAttachment.ParentId = scratchOrgId;
            authInfoAttachment.Body = Blob.valueOf(newCopadoScratchOrgInfo.authInfo);
            insert authInfoAttachment;

            // Call Authorize ScratchOrg endpoint.
            SfdxAPI.authorizeExternalScratchOrg(scratchOrgId, newCopadoScratchOrgInfo.authInfo);
        } catch (Exception ex) {
            // Prepare status for failure
            statusResult = CliSfDataWrapper.StatusResult.ERROR.name();
            messageResult = ex.getMessage();
            if (!Test.isRunningTest()) {
                Database.rollback(sp);
            }
        }

        // Communicate the result to CLI
        return (JSON.serialize(new AuthGrantResultWrapper(statusResult, messageResult, environmentId, scratchOrgId)));
    }

    /**
     * Security check for the entire method
     * @return null or an error to show in CLI
     */
    private String securityCheck() {
        // OLS check
        List<String> objectLevelSecurityCheck = CliSecurityService.checkOLS(
            new List<String>{ Schema.SObjectType.Org__c.getName(), Schema.SObjectType.Environment__c.getName() }
        );
        if (!objectLevelSecurityCheck.isEmpty()) {
            return CliSfDataWrapper.jsonReturnResult(CliSfDataWrapper.StatusResult.ERROR.name(), Label.Insufficient_Access + objectLevelSecurityCheck);
        }
        // FLS check
        List<String> fieldLevelSecurityCheck = new List<String>();
        List<String> checkFlsOrgCredential = CliSecurityService.checkFLS(
            Schema.SObjectType.Org__c.getName(),
            new List<String>{
                Schema.SObjectType.Org__c.fields.Environment__c.getName(),
                Schema.SObjectType.Org__c.fields.Name.getName(),
                Schema.SObjectType.Org__c.fields.Username__c.getName(),
                Schema.SObjectType.Org__c.fields.Org_Type__c.getName(),
                Schema.SObjectType.Org__c.fields.Developer_Hub_Org__c.getName(),
                Schema.SObjectType.Org__c.fields.SFDC_Org_ID__c.getName()
            },
            Utilities.DML_Action.INS
        );
        if (!checkFlsOrgCredential.isEmpty()) {
            fieldLevelSecurityCheck.addAll(checkFlsOrgCredential);
        }
        List<String> checkFlsEnvironment = CliSecurityService.checkFLS(
            Schema.SObjectType.Org__c.getName(),
            new List<String>{
                Schema.SObjectType.Environment__c.fields.Name.getName(),
                Schema.SObjectType.Environment__c.fields.Org_ID__c.getName(),
                Schema.SObjectType.Environment__c.fields.Type__c.getName()
            },
            Utilities.DML_Action.INS
        );
        if (!checkFlsEnvironment.isEmpty()) {
            fieldLevelSecurityCheck.addAll(checkFlsOrgCredential);
        }
        if (!fieldLevelSecurityCheck.isEmpty()) {
            return CliSfDataWrapper.jsonReturnResult(CliSfDataWrapper.StatusResult.ERROR.name(), Label.Insufficient_Access + fieldLevelSecurityCheck);
        }
        return null;
    }

    /**
     * Retrieves salesforce record for the Devhub
     */
    private List<Org__c> getDevHubCopado(AuthGrantWrapper scratchOrgInfo) {
        return [
            SELECT Id
            FROM Org__c
            WHERE
                Username__c = :scratchOrgInfo.devHubUserName
                AND Environment__r.Org_ID__c = :scratchOrgInfo.devHubOrgId
                AND is_Developer_Hub_Org__c = TRUE
            LIMIT 1
        ];
    }

    /**
     * Checks info retrieved from CLI
     */
    private String checkScrathcOrgInfo(List<Org__c> devHubCopado, AuthGrantWrapper scratchOrgInfo) {
        if (devHubCopado.isEmpty()) {
            return 'Dev Hub does not exist';
        }
        if (existScratchOrg(scratchOrgInfo.scratchOrgId)) {
            return 'This ScratchOrg already Exists';
        }
        if (String.isBlank(scratchOrgInfo.authInfo)) {
            return 'There is no auth info for this ScratchOrg';
        }
        return null;
    }

    /**
     * Checks if the scratchorg have been already created.
     */
    private Boolean existScratchOrg(String scratchOrgId) {
        List<Org__c> newScratchOrg = [SELECT Id FROM Org__c WHERE SFDC_Org_ID__c = :scratchOrgId + '_' + UserInfo.getUserId()];
        return !newScratchOrg.isEmpty();
    }

    /**
     * Get environment if exists
     */
    private String getEnvironment(String environmentId) {
        List<Environment__c> environment = [SELECT Id FROM Environment__c WHERE Org_ID__c = :environmentId LIMIT 1];
        return environment.isEmpty() ? null : environment[0].Id;
    }

    @TestVisible
    private class AuthGrantWrapper {
        public String environmentName;
        public String devHubOrgId;
        public String devHubUserName;
        public String scratchOrgUserName;
        public String scratchOrgId;
        public String scratchOrgExpirationDate;
        public String authInfo;
    }

    @TestVisible
    private class AuthGrantResultWrapper extends CliSfDataWrapper {
        public String environmentId;
        public String orgCredentialId;
        public AuthGrantResultWrapper(String stat, String msg, String envId, String orgCredId) {
            status = stat;
            message = msg;
            environmentId = envId;
            orgCredentialId = orgCredId;
        }
    }
}