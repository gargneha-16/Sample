public with sharing class AutomationTemplateUpgrade implements CLIInterface {
    
    // PUBLIC

    public CLIInterface getInstance() {
        return new AutomationTemplateUpgrade();
    }

    public String run(CliProxy.CLIWrapper record) {
        List<AutomationTemplate> result = new List<AutomationTemplate>();

        for(Deployment__c automationTemplate : new DeploymentsSelector().byNameWithSteps(templateNames())) {
            result.add(asAutomationTemplate(automationTemplate));
        }

        return toResponse(result);
    }


    // PRIVATE
    
    private String toResponse(List<AutomationTemplate> automationTemplates) {
        Response result = new Response(CliSfDataWrapper.StatusResult.OK.name(), 'Templates loaded successfully', automationTemplates);
        
        return (JSON.serialize(result, true));
    }

    private AutomationTemplate asAutomationTemplate(Deployment__c deployment) {
        AutomationTemplate result = new AutomationTemplate();
        result.id = deployment.Id;
        result.label = deployment.Name;
        result.name = deployment.ApiName__c;
        result.isActive = deployment.Active__c;
        result.steps = asSteps(deployment.Steps__r);
        result.description = deployment.Description__c;

        return result;
    }

    private List<Step> asSteps(List<Step__c> deploymentSteps) {
        List<Step> result = new List<Step>();
        
        for(Step__c deploymentStep : deploymentSteps) {
            Step step = new Step();
            step.id = deploymentStep.Id;
            step.label = deploymentStep.Name;
            step.json = (StepJson) JSON.deserialize(deploymentStep.dataJson__c, StepJson.class);

            result.add(step);
        }
        
        return result;
    }

    private Set<String> templateNames() {
        Set<String> result = new Set<String>();

        for(Automation_Template_For_CLI__c cliTemplate : Automation_Template_For_CLI__c.getAll().values()) {
            result.add(cliTemplate.Automation_Template_Name__c);
        }

        return result;
    }

    public class AutomationTemplate { 
        public String id;
        public String name;
        public String label;
        public Boolean isActive;
        public List<Step> steps;
        public String description;
    }

    public class Step { 
        public String id;
        public String label;
        public StepJson json;
    }

    public class StepJson { 
        public String type;
        public String flowApiName;
        public String functionAPIName;
        public List<List<String>> flowParameters;
        public List<Parameter> functionParameters;
    }

    // INNER

    @TestVisible
    private class Response extends CliSfDataWrapper {
        List<AutomationTemplate> automationTemplates;

        public Response(String stat, String msg, List<AutomationTemplate> templates) {
            status = stat;
            message = msg;
            automationTemplates = templates;
        }
    }
}