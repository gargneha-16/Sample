public inherited sharing class SObjectExpression extends DynamicExpression {

    private static final Pattern FIELD_PATTERN = Pattern.compile('(?i)\\{\\$?(Context).([A-Za-z0-9_.]+)\\}');
    private static final Pattern JSON_PATTERN = Pattern.compile('(?i)\\{\\$?(Context).([A-Za-z0-9_.]*DataJson).([A-Za-z0-9-_.]+)\\}');
    private static final Pattern JOB_EXECUTION_PATTERN = Pattern.compile('(?i)\\{\\$?(Job).(ExecutionParent).([A-Za-z0-9-_.]+)\\}');

    private SObject record;
    private SObject parentRecord;

    // CONSTRUCTOR

    public SObjectExpression(String contextId) {
        this.contextId = contextId;
    }


    // PUBLIC


    public override void prepare() {
        try {
            record = record();
            parentRecord = parentRecord();
        }
        catch (Exception ex) {
            throw new CopadoFunctionException(ex.getMessage() + ex.getStackTraceString());
        }
    }


    public override Boolean matches(Parameter parameter) {
        Matcher matcher1 = FIELD_PATTERN.matcher(parameter.value);
        Matcher matcher2 = JSON_PATTERN.matcher(parameter.value);
        Matcher matcher3 = JOB_EXECUTION_PATTERN.matcher(parameter.value);

        return matcher1.matches() || matcher2.matches() || matcher3.matches();
    }


    public override void parse(Parameter parameter) {
        Matcher matcher1 = FIELD_PATTERN.matcher(parameter.value);
        Matcher matcher2 = JSON_PATTERN.matcher(parameter.value);
        Matcher matcher3 = JOB_EXECUTION_PATTERN.matcher(parameter.value);

        if(matcher3.matches()) {
            String fieldName = matcher3.group(3);
            parameter.value = getValue(parentRecord, fieldName);
        }
        else if(matcher2.matches()) {
            String fieldName = matcher2.group(2);
            fieldName = fieldName.replace('DataJson', 'DataJson__c');
            String jsonValue = getValue(record, fieldName);

            parameter.value = getValueFromJson(jsonValue, matcher2.group(3));
        }
        else if(matcher1.matches()) {
            String propertyName = matcher1.group(2);
            parameter.value = getValue(record, propertyName);
        }
    }


    // PRIVATE


    private SObject record() {
        SObject result = null;
        List<String> fields = fields();

        if(!fields.isEmpty()) {
            String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + objectName(contextId) + ' WHERE Id =:contextId WITH SECURITY_ENFORCED';
            result = Database.query( String.escapeSingleQuotes(query) ).get(0);
        }

        return result;
    }


    private List<String> fields() {
        Set<String> result = new Set<String>();

        for(Parameter parameter : parameters) {
            Matcher matcher1 = FIELD_PATTERN.matcher(parameter.value);
            Matcher matcher2 = JSON_PATTERN.matcher(parameter.value);
            Matcher matcher3 = JOB_EXECUTION_PATTERN.matcher(parameter.value);

            if(matcher3.matches()) {
                continue;
            }
            else if(matcher2.matches()) {
                String fieldName = matcher2.group(2);
                fieldName = fieldName.replace('DataJson', 'DataJson__c');
                result.add(fieldName);
            }
            else if(matcher1.matches()) {
                String fieldName = matcher1.group(2);
                result.add(fieldName);
            }
        }

        return new List<String>(result);
    }


    private SObject parentRecord() {
        SObject result = null;
        List<String> fields = parentFields();
        String objectName = objectName(contextId);

        if(fields.isEmpty()) {
            return result;
        }

        if(objectName != 'JobStep__c') {
            throw new CopadoFunctionException(Label.invalidExecutionParentContext);
        }

        List<JobStep__c> steps = [SELECT Id, JobExecution__r.ParentId__c FROM JobStep__c WHERE Id = :contextId WITH SECURITY_ENFORCED];
        if(steps.isEmpty()) {
            throw new CopadoFunctionException(Label.invalidJobStepId);
        } else if(String.isBlank(steps[0].JobExecution__r.ParentId__c)) {
            throw new CopadoFunctionException(Label.executionParentRequired);
        }

        Id parentId = steps[0].JobExecution__r.ParentId__c;
        String parentName = objectName(parentId);

        String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + parentName + ' WHERE Id =:parentId WITH SECURITY_ENFORCED';
        result = Database.query( String.escapeSingleQuotes(query) ).get(0);

        return result;
    }


    private List<String> parentFields() {
        Set<String> result = new Set<String>();

        for(Parameter parameter : parameters) {
            Matcher matcher = JOB_EXECUTION_PATTERN.matcher(parameter.value);

            if(matcher.matches()) {
                String fieldName = matcher.group(3);
                result.add(fieldName);
            }
        }

        return new List<String>(result);
    }
}