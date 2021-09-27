public with sharing class AutomationTemplateService implements CLIInterface {
    
    // PUBLIC

    public CLIInterface getInstance() {
        return this;
    }

    public String run(CliProxy.CLIWrapper record) {
        Request request = (Request) JSON.deserialize(record.body, Request.class);
        assertFormat(request.stepJsonById);
        Id result = AutomationTemplateExecuter.execute(request.templateId, request.stepJsonById);

        return toResponse(result);
    }


    // PRIVATE
    
    private void assertFormat(Map<Id, String> stepJsonById) {
        try {
            if(stepJsonById != null && !stepJsonById.isEmpty()) {
                for(String serializedJson : stepJsonById.values()) {
                    AutomationTemplateUpgrade.StepJson stepJson = (AutomationTemplateUpgrade.StepJson) JSON.deserialize(serializedJson, AutomationTemplateUpgrade.StepJson.Class);
                }   
            }
        } catch (Exception ex) {
            System.debug(ex.getMessage());
            throw new CliException('Invalid Parameter format, please check the parameter file format using sfdx copado:automation:help --json command.');
        }
    }

    private String toResponse(Id automationId) {
        Response result = new Response(CliSfDataWrapper.StatusResult.OK.name(), 'Queued', automationId);
        
        return (JSON.serialize(result));
    }

    // INNER

    @TestVisible
    public class Response extends CliSfDataWrapper {
        Id automationId;

        public Response(String stat, String msg, Id recordId) {
            status = stat;
            message = msg;
            automationId = recordId;
        }
    }

    public class Request { 
        public Id templateId;
        public Map<Id, String> stepJsonById;
    }
}