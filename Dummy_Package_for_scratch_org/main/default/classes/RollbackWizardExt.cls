public with sharing class RollbackWizardExt extends DeploymentHelper {
    private Promotion__c promotion;
    private Deployment__c lastDeployment;

    // CTOR

    public RollbackWizardExt(ApexPages.StandardController stdCtrl) {
        if (!Test.isRunningTest()) {
            stdCtrl.addFields(new List<String>(Schema.SObjectType.Promotion__c.fields.getMap().keySet()));
        }

        promotion = (Promotion__c) stdCtrl.getRecord();
        List<Deployment__c> deployments = [
            SELECT Name, From_Org__c, Status__c, (SELECT To_Org__c, To_Org__r.Environment__r.Enable_Rollback__c FROM Destination_Orgs__r LIMIT 1)
            FROM Deployment__c
            WHERE Promotion__c = :promotion.Id
            WITH SECURITY_ENFORCED
            ORDER BY lastModifiedDate DESC
            LIMIT 1
        ];
        if (!deployments.isEmpty()) {
            lastDeployment = deployments[0];
        } else {
            addErrorMessage(Label.RollbackNoEligibleSteps);
        }
    }

    // PUBLIC
    public PageReference redirectToCorrectPage() {
        if (!pageMessagesMap.isEmpty()) {
            return null;
        }

        String rollbackDeploymentName = 'Rollback ' + lastDeployment.Name;
        List<Deployment__c> lastRollbackDeployment = [
            SELECT Name, Deployment_Last_Step__c
            FROM Deployment__c
            WHERE Name = :rollbackDeploymentName
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (!lastRollbackDeployment.isEmpty()) {
            deployment = deploymentWillBeRedirected = lastRollbackDeployment[0];
        } else {
            Deployment__c rollbackDeployment = new Deployment__c(Name = rollbackDeploymentName, Rolled_Back_Deployment__c = lastDeployment.Id);

            try {
                Utilities.Secure_DML(rollbackDeployment, Utilities.DML_Action.INS, schema.SObjectType.Deployment__c);
            } catch(Exception e) {
                addErrorMessage(Label.Insufficient_Access_Rights + ': ' + Label.Related_Object + ' ' + Schema.SObjectType.Deployment__c.getLabel());
                return null;
            }

            Destination_org__c rollbackDestination = new Destination_org__c(
                To_Org__c = lastDeployment.Destination_Orgs__r[0].To_Org__c,
                Deployment__c = rollbackDeployment.Id
            );

            try {
                Utilities.Secure_DML(rollbackDestination, Utilities.DML_Action.INS, schema.SObjectType.Destination_org__c);
            } catch(Exception e) {
                addErrorMessage(
                    Label.Insufficient_Access_Rights +
                    ': ' +
                    Label.Related_Object +
                    ' ' +
                    Schema.SObjectType.Destination_org__c.getLabel()
                );
                return null;
            }

            deployment = deploymentWillBeRedirected = rollbackDeployment;
        }

        initializeServiceClasses();
        return goToNextStep();
    }
}