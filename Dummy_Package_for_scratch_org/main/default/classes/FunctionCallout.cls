public with sharing class FunctionCallout extends HttpCallout {
    private static final Boolean AUTOMATED_PROCESS = UserInfo.getUserType() == 'AutomatedProcess';
    private String resultId;
    private String payload;
    private String contextId;

    public FunctionCallout(String resultId) {
        if (namedCredentialExists()) {
        super('callout:' + Settings.functionsNamedCredential, HttpMethod.POST);
        this.resultId = resultId;
        } else {
            throw new FunctionCalloutException(
                String.format(Label.Endpoint_not_Found, new List<String>{ String.valueOf(Settings.functionsNamedCredential) })
            );
        }
    }

    public FunctionCallout payload(String payload) {
        this.payload = payload;
        return this;
    }

    public FunctionCallout contextId(String contextId) {
        this.contextId = contextId;
        return this;
    }

    /**
     * @exception throws Exception. Make sure to handle it from the calling context.
     */
    public FunctionCallout build() {
        setHeaders();
        body(payload);
        path('/function/' + resultId);
        timeout(120000);

        return this;
    }

    public override Object processResponse() {
        HttpResponse response = response();
        Integer statusCode = response.getStatusCode();
        if (statusCode != 200 && statusCode != 201) {
            update Security.stripInaccessible(
                    AccessType.UPDATABLE,
                    new List<Result__c>{
                        new Result__c(
                            Id = resultId,
                            End_Time__c = Datetime.now(),
                            Status__c = 'Failed',
                            Progress_Status__c = Label.Error,
                    Error_Message__c = response.getBody(),
                    Error_Code__c = String.valueOf(statusCode)
                )
                    }
                )
                .getRecords();

                Result__c result = new ResultsSelector().byid(resultId);
                new HandleBackendResponse().resultCallback(new FunctionsSelector().byId(result.Function__c), resultId, 'Error');
        } else {
            if (resultMonitor().isEmpty()) {
                FunctionResultMonitor.start();
            }
        }
        return response;
    }

    private void setHeaders() {
        User user = user();
        header('userId', user.Id);
        header('user-email', user.Email);
        header('user-name', user.Name);
        header('copado-url', Settings.server_url);
        header('copado-namespace', Settings.ns);
        header('Content-Type', 'application/json');
        header('token2', DeployAPI.getAuthToken2(user.Id));
        header('orgId', UserInfo.getOrganizationId());
        header('copado-api-key', apiKey(user.Id));
    }

    // To avoid creating remote site settings for the named credential endpoint, we only query it to check if it exists
    // and then reference it using the 'callout:namedCredential' notation. This will allow us to throw our own expection,
    // as opposed to having Salesforce throw an UnexpectedException, which cannot be caught.
    private Boolean namedCredentialExists() {
        String name = Settings.functionsNamedCredential.replace(Settings.ns, '');
        List<NamedCredential> result = [SELECT Id FROM NamedCredential WHERE DeveloperName = :name];

        return !result.isEmpty();
    }

    private User user() {
        User user;

        if (AUTOMATED_PROCESS) {
            user = [SELECT Email, Name FROM User WHERE Id = :ownerId()];
        } else {
            user = [SELECT Email, Name FROM User WHERE Id = :UserInfo.getUserId()];
        }

        return user;
    }

    private String apiKey(Id userId) {
        String result;

        if (AUTOMATED_PROCESS) {
            result = ownerKey(userId);
        } else {
            result = new Settings().mySettings.API_Key__c;
        }

        return result;
    }

    private List<Crontrigger> resultMonitor() {
        return [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'FunctionResultMonitor%' LIMIT 1];
    }

    private String ownerKey(Id userId) {
        return DeployAPI.decryptAPIKey([SELECT API_Key__c FROM Personal_Settings__c WHERE SetupOwnerId = :userId LIMIT 1]?.API_Key__c);
    }

    private Id ownerId() {
        Id result;
        String objectType = objectType();

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
            throw new FunctionCalloutException(Label.Context_Owner_Not_Found);
        }

        return result;
    }

    private String objectType() {
        return String.isNotBlank(contextId) ? Id.valueOf(contextId).getSObjectType().getDescribe().getLocalName() : '';
    }

    private class FunctionCalloutException extends CopadoFunctionException {
    }
}