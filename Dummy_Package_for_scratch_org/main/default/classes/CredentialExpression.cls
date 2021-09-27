@SuppressWarnings('PMD.CyclomaticComplexity')
public inherited sharing class CredentialExpression extends DynamicExpression {
    private static final Boolean AUTOMATED_PROCESS = UserInfo.getUserType() == 'AutomatedProcess';

    private static final String CONTEXT_REGEX1 = '(?i)\\{\\$?Context.Credential.(Endpoint|SessionId)\\}';
    private static final String CONTEXT_REGEX2 = '(?i)\\{\\$?(Source|Destination).Credential.(Endpoint|SessionId)\\}';

    private static final Pattern CONTEXT_PATTERN1 = Pattern.compile(CONTEXT_REGEX1);
    private static final Pattern CONTEXT_PATTERN2 = Pattern.compile(CONTEXT_REGEX2);

    private SObject record;
    private String objectName;
    private Map<Id, Org__c> credentialByEnvironment = new Map<Id, Org__c>();

    // CONSTRUCTOR

    public CredentialExpression(String contextId) {
        this.contextId = contextId;
    }

    // PUBLIC

    public override Boolean matches(Parameter parameter) {
        return (CONTEXT_PATTERN1.matcher(parameter.value).matches() || CONTEXT_PATTERN2.matcher(parameter.value).matches());
    }

    public override void prepare() {
        objectName = objectName(recordId());

        if (String.isNotBlank(objectName) && objectName.equalsIgnoreCase('Deployment_Job__c')) {
            record = [SELECT Source_Id__c, Destination_Id__c FROM Deployment_Job__c WHERE Id = :contextId WITH SECURITY_ENFORCED];
        } else if (String.isNotBlank(objectName) && objectName.equalsIgnoreCase('JobStep__c')) {
            record = [SELECT Source_Id__c, Destination_Id__c FROM JobStep__c WHERE Id = :contextId WITH SECURITY_ENFORCED];
        }

        credentialByEnvironment = credentialByEnvironment();

        assertRecordIdExpression();
    }

    public override void parse(Parameter parameter) {
        Matcher contextMatcher1 = CONTEXT_PATTERN1.matcher(parameter.value);
        Matcher contextMatcher2 = CONTEXT_PATTERN2.matcher(parameter.value);
        String value = null;

        if (contextMatcher1.matches()) {
            WebhookCallout.Credential credential = getCredential(contextId);
            String propertyName = contextMatcher1.group(1);

            value = propertyName.equalsIgnoreCase('Endpoint') ? credential.endPoint : credential.sessionId;
        } else if (contextMatcher2.matches()) {
            String orgType = contextMatcher2.group(1);
            String propertyName = contextMatcher2.group(2);

            Id environmentId = orgType == 'Source' ? getSourceId() : getDestinationId();

            WebhookCallout.Credential credential = getCredential(environmentId);

            value = propertyName.equalsIgnoreCase('Endpoint') ? credential.endPoint : credential.sessionId;
        }

        parameter.value = value;
        parameter.sensitive = true;
    }

    // PRIVATE

    private Id recordId() {
        try {
            return Id.valueOf(contextId);
        } catch (Exception ex) {
            throw new CopadoFunctionException(
                String.format(
                    Label.invalidContextId,
                    new List<String>{ Label.DEPLOYMENT_JOB + ' / ' + Label.JobStep + ' / ' + Label.USDependency_Environment }
                )
            );
        }
    }

    private Id getSourceId() {
        return (Id) record.get('Source_Id__c');
    }

    private Id getDestinationId() {
        return (Id) record.get('Destination_Id__c');
    }

    private Map<Id, Org__c> credentialByEnvironment() {
        Map<Id, Org__c> result = new Map<Id, Org__c>();

        Set<Id> environmentIds = environmentIds();

        for (Environment__c environment : [
            SELECT Id, (SELECT Id, Default_Credential__c, OwnerId, Environment__r.Platform__c FROM Org_Credentials__r)
            FROM Environment__c
            WHERE Id IN :environmentIds
            WITH SECURITY_ENFORCED
        ]) {
            result.put(environment.Id, userCredential(environment.Org_Credentials__r));
        }

        return result;
    }

    private Org__c userCredential(List<Org__c> orgs) {
        Org__c result = null;

        for (Org__c org : orgs) {
            if (org.OwnerId == UserInfo.getUserId() || org.Default_Credential__c == true) {
                result = org;
                break;
            }
        }

        return result;
    }

    private void assertRecordIdExpression() {
        for (Parameter parameter : parameters) {
            Matcher contextMatcher1 = CONTEXT_PATTERN1.matcher(parameter.value);

            if (contextMatcher1.matches() && objectName(contextId) != 'Environment__c') {
                throw new CopadoFunctionException(String.format(Label.invalidContextId, new List<String>{ Label.Org_Credential }));
            }
        }
    }

    private Set<Id> environmentIds() {
        Set<Id> result = new Set<Id>();

        if (objectName(contextId) == 'Environment__c') {
            result.add(contextId);
        }

        if (record != null) {
            result.add(getSourceId());
            result.add(getDestinationId());
        }

        return result;
    }

    private WebhookCallout.Credential getCredential(Id environmentId) {
        Org__c org = credentialByEnvironment.get(environmentId);

        if (org == null) {
            throw new CopadoFunctionException(Label.credentialNotAvailable + environmentId);
        }

        String clientKey = [SELECT Text_Field__c FROM Copado_Protected_Settiing__mdt WHERE DeveloperName = 'FunctionCredentialClientKey' LIMIT 1]
        .Text_Field__c;

        HttpCallout callout = new WebhookCallout(path(org.Id))
            .type(WebhookCallout.Credential.class)
            .header('Content-Type', 'application/json')
            .header('X-Client-Key', clientKey)
            .request();

        // TODO: ADD API KEY ERROR AND OTHER DETAILS
        if (callout.response().getStatusCode() != 200) {
            throw new CopadoFunctionException(Label.InvalidRequest);
        }

        WebhookCallout.Credential result = (WebhookCallout.Credential) callout.parseResponse();

        if (result.isSuccess != true) {
            throw new CopadoFunctionException(result.error);
        }

        return result;
    }

    private String path(Id orgId) {
        return Settings.server_url + '/json/v1/webhook/copadoSession/' + orgId + '?api_key=' + apiKey();
    }

    // Note: this runs as an Automated process user so not CRUD check needed
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private String apiKey() {
        User user = user();

        return DeployAPI.decryptAPIKey([SELECT API_Key__c FROM Personal_Settings__c WHERE SetupOwnerId = :user.Id LIMIT 1]?.API_Key__c);
    }

    // Note: this runs as an Automated process user so not CRUD check needed
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private User user() {
        User user;

        if (AUTOMATED_PROCESS) {
            user = [SELECT Email, Name FROM User WHERE Id = :ownerId()];
        } else {
            user = [SELECT Email, Name FROM User WHERE Id = :UserInfo.getUserId()];
        }

        return user;
    }

    @SuppressWarnings('PMD.ApexSOQLInjection')
    private Id ownerId() {
        Id result;
        String objectType = objectName(contextId);

        if (objectType == 'Deployment_Job__c') {
            result = [SELECT Step__r.Deployment__r.OwnerId FROM Deployment_Job__c WHERE Id = :contextId WITH SECURITY_ENFORCED]
            ?.Step__r.Deployment__r.OwnerId;
        } else if(objectType == 'JobStep__c') {
            result = [SELECT Parent_Owner_Id__c FROM JobStep__c WHERE Id = :contextId WITH SECURITY_ENFORCED]?.Parent_Owner_Id__c;
		} else {
            String query = 'SELECT OwnerId FROM ' + objectType + ' WHERE Id = :contextId WITH SECURITY_ENFORCED';

            List<SObject> records = Database.query(query);
            result = (records.isEmpty()) ? null : (Id) records[0].get('OwnerId');
        }

        if (String.isBlank(result)) {
            throw new ApplicationException(Label.Context_Owner_Not_Found);
        }

        return result;
    }
}