public with sharing class RollbackWizardStartExt extends DeploymentHelper {
    private List<String> stepTypesAvailableForRollback = new List<String>{ 'Git Promotion', 'Delete MetaData' };

    private List<String> deploymentStatusesForRollback = new List<String>{ 'Completed Successfully', 'Completed With Errors' };

    public RollbackWizardStartExt(ApexPages.StandardController stdCtrl) {
        if (!Test.isRunningTest()) {
            stdCtrl.addFields(new List<String>(Schema.SObjectType.Deployment__c.fields.getMap().keySet()));
        }
        Deployment__c rollbackDeployment = (Deployment__c) stdCtrl.getRecord();
        deployment = rollbackDeployment;
        initializeServiceClasses();
        populateNecessaryData();
        populateStepsList();
        populatePagesList();
    }

    // PUBLIC

    public PageReference saveAndGoToNextStep() {
        upsertDeployment(true);
        PageReference pageRef = pageMessagesMap.isEmpty() ? goToNextStep() : null;
        return pageRef;
    }

    // PRIVATE

    private void populateNecessaryData() {
        pageMessagesMap.clear();
        sourceList = new List<SourceWrapper>();

        if (!isRollbackAvailable()) {
            return;
        }

        try {
            for (Step__c step : [
                SELECT
                    Id,
                    Name,
                    Type__c,
                    Status__c,
                    CheckOnly__c,
                    Order__c,
                    (
                        SELECT Id
                        FROM ContentDocumentLinks
                        WHERE ContentDocument.Title = 'Rollback Index' OR ContentDocument.Title = 'Rollback Index.json'
                    )
                FROM Step__c
                WHERE Deployment__c = :deployment.Rolled_Back_Deployment__c
                WITH SECURITY_ENFORCED
                ORDER BY Order__c ASC
            ]) {
                String reason = getRollbackAvailability(step);
                sourceList.add(new SourceWrapper(step.Name, step.Type__c, step.Status__c, reason == '', reason));
            }
        } catch (Exception e) {
            addErrorMessage(
                Label.Insufficient_Access_Rights +
                ' ' +
                Label.Related_Object +
                ' ' +
                Schema.SObjectType.Step__c.getLabel() +
                '/' +
                Schema.SObjectType.ContentDocumentLink.getLabel()
            );
            return;
        }
    }

    private Boolean isRollbackAvailable() {
        try {
            Deployment__c rolledBackDeployment = [
                SELECT Status__c, (SELECT To_Org__c, To_Org__r.Environment__r.Enable_Rollback__c FROM Destination_Orgs__r LIMIT 1)
                FROM Deployment__c
                WHERE Id = :deployment.Rolled_Back_Deployment__c
                WITH SECURITY_ENFORCED
            ];

            if (!rolledBackDeployment.Destination_Orgs__r[0].To_Org__r.Environment__r.Enable_Rollback__c) {
                addErrorMessage(Label.RollbackNotEnabled);
                return false;
            }
        } catch (Exception e) {
            addErrorMessage(
                Label.Insufficient_Access_Rights +
                ': ' +
                Label.Related_Object +
                ' ' +
                Schema.SObjectType.Deployment__c.getLabel() +
                '/' +
                Schema.SObjectType.Destination_Org__c.getLabel()
            );
            return false;
        }

        if (!areAvailableSteps()) {
            return false;
        }

        if (!isDestinationOrgValidated()) {
            addErrorMessage(Label.DESTINATION_ORG_NOT_VALIDATED);
            return false;
        }

        return true;
    }

    private Boolean areAvailableSteps() {
        try {
            List<Step__c> steps = [
                SELECT
                    Id,
                    Name,
                    Type__c,
                    Status__c,
                    (
                        SELECT Id
                        FROM ContentDocumentLinks
                        WHERE ContentDocument.Title = 'Rollback Index.json' OR ContentDocument.Title = 'Rollback metadata.zip'
                    )
                FROM Step__c
                WHERE
                    Deployment__c = :deployment.Rolled_Back_Deployment__c
                    AND Type__c IN :stepTypesAvailableForRollback
                    AND Status__c IN :deploymentStatusesForRollback
                    AND CheckOnly__c = FALSE
                WITH SECURITY_ENFORCED
            ];

            if (steps.isEmpty()) {
                addErrorMessage(Label.RollbackNoEligibleSteps);
                return false;
            }

            for (Step__c step : steps) {
                if ((step.ContentDocumentLinks.isEmpty() || step.ContentDocumentLinks.size() < 2) && !Test.isRunningTest()) {
                    addErrorMessage(Label.RollbackMissingFiles);
                    return false;
                }
            }

            return true;
        } catch (Exception e) {
            addErrorMessage(Label.Insufficient_Access_Rights + ': ' + Label.Related_Object + ' ' + Schema.SObjectType.Step__c.getLabel());
            return false;
        }
    }

    private Boolean isDestinationOrgValidated() {
        Destination_Org__c destOrg = getDestinationOrg();
        if (destOrg.To_Org__c != null) {
            try {
                List<Org__c> orgs = new OrgsSelector().byId(new Set<Id>{ destOrg.To_Org__c });
                if (!orgs[0].Disable_Validation__c && orgs[0].Validated_Status__c != C_OK) {
                    return DeployAPI.validateOrg(destOrg.To_Org__c);
                }
                return true;
            } catch (Exception e) {
                addErrorMessage(Label.Insufficient_Access_Rights + ' ' + Label.Related_Object + ' ' + Schema.SObjectType.Org__c.getLabel());
            }
        } else {
            addErrorMessage(Label.RollbackMissingDestOrg);
        }
        return false;
    }

    private String getRollbackAvailability(Step__c step) {
        String result = '';

        if (!stepTypesAvailableForRollback.contains(step.Type__c)) {
            result = Label.RollbackStepTypeNotEligible;
        } else if (step.CheckOnly__c) {
            result = Label.RollbackValidationStepMessage;
        } else if (step.ContentDocumentLinks.isEmpty()) {
            result = Label.RollbackMissingFilesMessage;
        }

        return result;
    }
}