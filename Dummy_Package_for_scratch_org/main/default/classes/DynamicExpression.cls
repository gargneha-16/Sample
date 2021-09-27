public abstract class DynamicExpression {

    protected String contextId;
    protected List<Parameter> parameters = new List<Parameter>();


    // CONSTRUCTOR

    public void add(Parameter parameter) {
        if(matches(parameter)) {
            parameters.add(parameter);
        }
    }


    public virtual Boolean matches(Parameter parameter) {
        return true;
    }

    @SuppressWarnings('PMD.EmptyStatementBlock')
    public virtual void prepare() {}


    @SuppressWarnings('PMD.EmptyStatementBlock')
    public virtual void parse(Parameter parameter) {}

    public Boolean hasParameters() {
        return !parameters.isEmpty();
    }

    protected String getValue(SObject record, String fieldName) {
        if(record != null && fieldName.contains('.')) {
            return getValue((SObject) record?.getSobject(fieldName.substringBefore('.')), fieldName.substringAfter('.'));
        }
        else if(record != null) {
            return (String) record.get(fieldName);
        }
        else {
            return '';
        }
    }


    protected String objectName(String strRecordId) {
        Id recordId = String.isNotBlank(strRecordId) ? Id.valueOf(strRecordId) : null;

        return recordId?.getSobjectType()?.getDescribe()?.getLocalName();
    }


    protected Boolean matches(Pattern regexPattern, String expression) {
        return regexPattern.matcher(expression).matches();
    }


    protected String getValueFromJson(String jsonInput, String propertyName) {
        String result = null;

        if(!String.isBlank(jsonInput)) {
            Map<String, Object> jsonResult = (Map<String, Object>) JSON.deserializeUntyped(jsonInput);

            if(propertyName.contains('.')) {
                result = getValueFromJson(JSON.serialize(jsonResult.get(propertyName.substringBefore('.'))), propertyName.substringAfter('.'));
            }
            else if(jsonResult != null && jsonResult.containsKey(propertyName)) {
                result = JSON.serialize(jsonResult.get(propertyName));
            }
        }

        return trimQuotes(result);
    }


    protected String trimQuotes(String value) {
        return (value != null && value.startsWith('"') && value.endsWith('"')) ?
                    value.subString(1, value.length() - 1) :
                    value;
    }
}