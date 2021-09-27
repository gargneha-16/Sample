public with sharing class SetDefaultStepOrder {

    private List<Step__c> steps;

    // CONSTRUCTOR

    public SetDefaultStepOrder(List<Step__c> steps) {
        this.steps = steps;
    }

    // PUBLIC

    public void execute() {

        Id automationTemplateRecordTypeId = Schema.SObjectType.Deployment__c.getRecordTypeInfosByDeveloperName().get('Automation_Template').getRecordTypeId();

        List<Deployment__c> deployments = new DeploymentsSelector().byIdWithSteps(deploymentIds());

        Map<Id, Deployment__c> deploymentsById = new Map<Id, Deployment__c>(deployments);
        Map<Id, Integer> deploymentStepsSizeByDeploymentIds = new Map<Id, Integer>();
        for (Deployment__c deployment : deployments) {
            deploymentStepsSizeByDeploymentIds.put(deployment.Id, deployment.Steps__r.size());
        }
        
        // To be able set correct order to deployment steps which comes from user story deployment tasks(created by backend)
        // or created in an automation template
        Map<Id, Integer> stepOrderCounterByDeploymentId = new Map<Id, Integer>();
        for (Step__c step : steps) {
            step.ApiName__c = deploymentsById.get(step.Deployment__c).ApiName__c + '_' + step.Name;

            Boolean isEditableDeploymentTaskStep =
                deploymentStepsSizeByDeploymentIds.containsKey(step.Deployment__c) &&
                isValidType(step.Type__c) &&
                !step.Read_Only__c;

            Boolean isAutomationTemplateStep =
                deploymentsById.get(step.Deployment__c).RecordTypeId == automationTemplateRecordTypeId;

            if (isEditableDeploymentTaskStep || isAutomationTemplateStep) {
                if (stepOrderCounterByDeploymentId.containsKey(step.Deployment__c)) {
                    stepOrderCounterByDeploymentId.put(step.Deployment__c, stepOrderCounterByDeploymentId.get(step.Deployment__c) + 1);
                } else {
                    stepOrderCounterByDeploymentId.put(step.Deployment__c, 1);
                }

                Integer numberOfSiblingSteps = deploymentStepsSizeByDeploymentIds.containsKey(step.Deployment__c)
                    ? deploymentStepsSizeByDeploymentIds.get(step.Deployment__c)
                    : 0;
                step.Order__c = numberOfSiblingSteps + stepOrderCounterByDeploymentId.get(step.Deployment__c);
            }
        }
    }

    private Set<Id> deploymentIds() {
        Set<Id> result = new Set<Id>();
        for (Step__c step : steps) {
            result.add(step.Deployment__c);
        }

        return result;
    }
    
    private Boolean isValidType(String type) {
        Set<String> deploymentTaskTypes = new Set<String> {
            'Manual Task',
            'Data',
            'Bulk Data',
            'Data Template',
            'Delete Metadata',
            'Custom Settings',
            'Apex',
            'URL Callout',
            'Salesforce Flow'
        };

        return deploymentTaskTypes.contains(type);
    }
}