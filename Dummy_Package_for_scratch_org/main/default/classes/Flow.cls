public inherited sharing class Flow {
    private Id stepId;
    private String flowName;
    private String callback;
    private List<Parameter> parameters;

    @TestVisible
    private static Event__e mockResponse;


    // CONSTRUCTOR

    public Flow(Id stepId, String flowName) {
        this.stepId = stepId;
        this.flowName = flowName;
    }


    // PUBLIC

    public Id execute() {
        Result__c result = result();
        insert result;

        try {
            parameters = new TemplatingEngine(stepId, parameters).parse();

            if(Test.isRunningTest()) {
                mockResponse.Topic_Uri__c += result.Id;
                Eventbus.publish(mockResponse);
            }
            else {
                Map<String, String> flowParameter = asMap(parameters);
                flowParameter.put('resultId', result.Id);

                Flow.Interview.createInterview(namespace(flowName), localName(flowName), flowParameter).start();
            }
        }
        catch(Exception ex) {
            result.Status__c = 'Error';
            result.Error_Message__c = ex.getMessage();
            update result;

            Event__e stepCompleted = new Event__e();
            stepCompleted.Payload__c = asPayload(false, ex.getMessage());
            stepCompleted.Topic_Uri__c = OnJobStepComplete.STEP_ENDPOINT + result.Id;
            EventBus.publish(stepCompleted);
        }

        return result.Id;
    }


    public Flow resultCallback(String callback) {
        this.callback = callback;

        return this;
    }


    public Flow parameters(List<Parameter> parameters) {
        this.parameters = parameters;

        return this;
    }


    // PRIVATE

    private Map<String, String> asMap(List<Parameter> parameters) {
        Map<String, String> result = new Map<String, String>();

        for(Parameter parameter : parameters) {
            result.put(parameter.name, parameter.value);
        }

        return result;
    }


    private Result__c result() {
        Result__c result = new Result__c();
        result.JobStep__c = stepId;
        result.Job_Type__c = flowName;
        result.ParentId__c = stepId;
        result.Status__c = 'In Progress';
        result.ApexCallback__c = callback;
        result.Start_Time__c = Datetime.now();

        return (Result__c) Security.stripInaccessible(AccessType.CREATABLE, new List<SObject> { result }).getRecords().get(0);
    }


    private String asPayload(Boolean isSuccess, String message) {
        OnJobStepComplete.EventPayload result = new OnJobStepComplete.EventPayload(isSuccess, message);

        return JSON.serialize(result);
    }


    private String namespace(String name) {
        return name.contains('.') ? name.substringBefore('.') : '';
    }


    private String localName(String name) {
        return name.contains('.') ? name.substringAfter('.') : name;
    }
}