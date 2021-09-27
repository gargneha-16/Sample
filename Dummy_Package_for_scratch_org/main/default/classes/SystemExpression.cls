public inherited sharing class SystemExpression extends DynamicExpression {
    private static final String CONTEXT_REGEX1 = '(?i)\\{\\$?(Source|Destination|Pipeline).([A-Za-z0-9_.]+)\\}';
    private static final String CONTEXT_REGEX2 = '(?i)\\{\\$?(Source|Destination|Pipeline|User).Property.([A-Za-z0-9_]+)\\}';

    private static final Pattern CONTEXT_PATTERN1 = Pattern.compile(CONTEXT_REGEX1);
    private static final Pattern CONTEXT_PATTERN2 = Pattern.compile(CONTEXT_REGEX2);

    private SObject record;
    private Map<Id, SObject> recordsByParentId;
    private Map<String, System_Property__c> propertiesByUId;

    private Map<Id, Set<String>> fieldsByParentIds = new Map<Id, Set<String>>();
    private Set<String> uIds = new Set<String>();

    // CONSTRUCTOR

    public SystemExpression(String contextId) {
        this.contextId = contextId;
    }

    // PUBLIC

    public override Boolean matches(Parameter parameter) {
        return (CONTEXT_PATTERN1.matcher(parameter.value).matches() || CONTEXT_PATTERN2.matcher(parameter.value).matches());
    }

    public override void prepare() {
        String objectName = objectName(recordId());

        if (String.isNotBlank(objectName) && objectName.equalsIgnoreCase('Deployment_Job__c')) {
            record = [SELECT Source_Id__c, Destination_Id__c, Pipeline_Id__c FROM Deployment_Job__c WHERE Id = :contextId WITH SECURITY_ENFORCED];
        } else if (String.isNotBlank(objectName) && objectName.equalsIgnoreCase('JobStep__c')) {
            record = [SELECT Source_Id__c, Destination_Id__c, Pipeline_Id__c FROM JobStep__c WHERE Id = :contextId WITH SECURITY_ENFORCED];
        }

        try {
            parseExpressions();
            propertiesByUId = new SystemPropertiesSelector().byUID(uIds);
            recordsByParentId = recordsByParentId();
        } catch (Exception ex) {
            throw new CopadoFunctionException(ex.getMessage());
        }
    }

    public override void parse(Parameter parameter) {
        String value = parameter.value;

        Matcher contextMatcher1 = CONTEXT_PATTERN1.matcher(value);
        Matcher contextMatcher2 = CONTEXT_PATTERN2.matcher(value);

        if (contextMatcher2.matches()) {
            String contextType = contextMatcher2.group(1);
            String propertyName = contextMatcher2.group(2);
            String uID = parentId(contextType) + '-' + propertyName;

            if (propertiesByUId.containsKey(uID)) {
                System_Property__c systemProperty = propertiesByUId.get(uID);
                parameter.value = systemProperty?.Value__c;
                parameter.sensitive(systemProperty?.Is_Sensitive__c);
            } else {
                throw new CopadoFunctionException(Label.InValidProperty + propertyName);
            }
        } else if (contextMatcher1.matches()) {
            String contextType = contextMatcher1.group(1);
            String propertyName = contextMatcher1.group(2);
            String parentId = parentId(contextType);

            SObject record = recordsByParentId.get(parentId);
            parameter.value = getValue(record, propertyName);
        }
    }

    // PRIVATE

    private Id recordId() {
        try {
            return Id.valueOf(contextId);
        } catch (Exception ex) {
            throw new CopadoFunctionException(
                String.format(Label.invalidContextId, new List<String>{ Label.DEPLOYMENT_JOB + ' / ' + Label.JobStep })
            );
        }
    }

    private void parseExpressions() {
        for (Parameter parameter : parameters) {
            String value = parameter.value;

            Matcher contextMatcher1 = CONTEXT_PATTERN1.matcher(value);
            Matcher contextMatcher2 = CONTEXT_PATTERN2.matcher(value);

            if (contextMatcher2.matches()) {
                String contextType = contextMatcher2.group(1);
                String propertyName = contextMatcher2.group(2);

                uIds.add(parentId(contextType) + '-' + propertyName);
            } else if (contextMatcher1.matches()) {
                String contextType = contextMatcher1.group(1);
                String propertyName = contextMatcher1.group(2);
                Id parentId = Id.valueOf(parentId(contextType));
                if (!fieldsByParentIds.containsKey(parentId)) {
                    fieldsByParentIds.put(parentId, new Set<String>());
                }

                fieldsByParentIds.get(parentId).add(propertyName);
            }
        }
    }

    // NOTE: The SOQL query inside loop is necessary because parameter support polymorphic record Ids(false positive)
    @SuppressWarnings('PMD.OperationWithLimitsInLoop')
    private Map<Id, Sobject> recordsByParentId() {
        Map<Id, Sobject> result = new Map<Id, Sobject>();

        for (Id parentId : fieldsByParentIds.keySet()) {
            String objectName = objectName(parentId);
            List<String> fields = new List<String>(fieldsByParentIds.get(parentId));
            String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + objectName + ' WHERE Id = :parentId WITH SECURITY_ENFORCED';
            SObject record = Database.query(String.escapeSingleQuotes(query));

            result.put(parentId, record);
        }

        return result;
    }

    private Id parentId(String contextType) {
        String result = null;

        if (contextType.equalsIgnoreCase('User')) {
            result = UserInfo.getUserId();
        } else {
            String fieldName = contextType + '_Id__c';
            result = (String) record?.get(fieldName);
        }

        return result != null ? result : null;
    }
}