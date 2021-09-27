/**
 * @description Builds the payload for the Copado Function callout.
 * @exception throws JSONException. Make sure to handle it from the calling context.
 */
public with sharing class FunctionPayload {
    private String function;
    private String script;
    private String resultId;
    private String image;
    private List<Parameter> options;
    private List<Parameter> parameters;

    // CTOR

    public FunctionPayload(Function__c function) {
        this.function = function.API_Name__c;
        this.script = function.Script__c;
        this.image = function.Image_Name__c;
        options(function);
    }

    // PUBLIC

    public FunctionPayload options(List<Parameter> options) {
        if (options != null) {
            if (this.options == null) {
                this.options = new List<Parameter>();
            }
            this.options.addAll(options);
        }
        return this;
    }

    public FunctionPayload parameters(List<Parameter> parameters) {
        this.parameters = parameters;
        return this;
    }

    public FunctionPayload resultId(String resultId) {
        this.resultId = resultId;
        return this;
    }

    public String getResultId() {
        return this.resultId;
    }

    /**
     * @exception throws Exception. Make sure to handle it from the calling context.
     */
    public FunctionPayload validate(String functionParams) {
        Map<String, String> parameterMap = new Map<String, String>();
        for (Parameter parameter : parameters) {
            parameterMap.put(parameter.name, parameter.value);
        }
        List<Parameter> baseParams = (List<Parameter>) JSON.deserialize(functionParams, List<Parameter>.class);
        for (Parameter parameter : baseParams) {
            Boolean required = Boolean.valueOf(parameter.required);
            if (required) {
                String name = String.valueOf(parameter.name);
                String value = parameterMap.get(name);
                if (String.isBlank(value)) {
                    throw new FunctionPayloadException(
                        Label.Required_Parameters_Missing +
                        ': ' +
                        name +
                        '. ' +
                        Label.Value_not_Found +
                        ': ' +
                        parameter.defaultValue
                    );
                }
            }
        }

        return this;
    }

    public String toJson() {
        return JSON.serialize(this);
    }

    // PRIVATE

    private void options(Function__c record) {
        if (String.isNotBlank(record.Options__c)) {
            this.options = (List<Parameter>) JSON.deserialize(record.Options__c, List<Parameter>.class);
        }
        if (String.isNotBlank(record.Worker_Size__c)) {
            if (this.options == null) {
                this.options = new List<Parameter>();
            }
            this.options.add(new Parameter('workerSize', record.Worker_Size__c));
        }
    }

    private class FunctionPayloadException extends Exception {
    }
}