@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class Function implements Queueable, Database.AllowsCallouts {
    private Boolean automatedProcess = UserInfo.getUserType() == 'AutomatedProcess';

    private Result__c result;
    private Function__c function;
    private FunctionPayload payload;
    private List<Parameter> parameters;
    private List<Parameter> options;
    private Id stepId;
    private String contextId;
    private String resultCallback;
    private final String apiName;
    private Boolean showValidationErrors = false;
    private Boolean isValidCredential = true;

    @TestVisible
    private static MC_Result__e mockResponse;

    // CONSTRUCTOR

    public Function(String apiName) {
        this.apiName = apiName;
    }

    // PUBLIC

    public Function contextId(String contextId) {
        this.contextId = contextId;
        return this;
    }

    public Function stepId(Id stepId) {
        this.stepId = stepId;
        return contextId(stepId);
    }

    public Function parameters(List<Parameter> parameters) {
        this.parameters = parameters;
        return this;
    }

    public Function options(List<Parameter> options) {
        this.options = options;
        return this;
    }

    public Function resultCallback(String resultCallback) {
        this.resultCallback = resultCallback;
        return this;
    }

    public Function showValidationErrors(Boolean showValidationErrors) {
        this.showValidationErrors = showValidationErrors;
        return this;
    }

    public Id execute() {
        try {
            function = new FunctionsSelector().byApiName(apiName);
            parameters = new TemplatingEngine(contextId, parameters).parse();
            isValidCredential = UserInfo.getUserType() == 'AutomatedProcess' || isValidCredential();
            result = createResult();
            validateFunction();
            if(Test.isRunningTest() && mockResponse != null) {
                mockResponse.ResultId__c = result.Id;
                Eventbus.publish(mockResponse);
            } else {
                verifyUser();
                checkCredits();
                payload = payload();
                System.enqueueJob(this);
            }
        } catch (Exception ex) {
            // needed for ease of internal troubleshooting when an error occurs in a subscriber org.
            System.debug(LoggingLevel.ERROR, 'error: ' + ex.getMessage() + ': ' + ex.getStackTraceString());
            CopadoFunctionException error = error(ex);
            if (showValidationErrors) {
                throw error;
            }
        }

        return result.Id;
    }

    public void execute(QueueableContext ctx) {
        try {
            new FunctionCallout(result.Id).payload(payload.toJson()).contextId(contextId).build().request().parseResponse();
        } catch (Exception ex) {
            error(ex);
        }
    }

    // PRIVATE

    private void verifyUser() {
        if (!automatedProcess) {
            checkLicense();
            checkAPIKey();
            checkCredential();
        }
    }

    private void checkLicense() {
        if (!FeatureHelper.isFunctionEnabled()) {
            throw new CopadoFunctionException(Label.FunctionNotEnabled);
        }
    }

    private void checkCredits() {
        if (isFunctionCustom(function)) {
            if (hardLimitReached()) {
                throw new CopadoFunctionException(Label.Function_Credit_Limit_Exceeded);
            }

            if(monthlyUsage().isEmpty()) {
                resetCredits();
            }
        }
    }

    private Boolean isFunctionCustom(Function__c function) {
        return function.Type__c != 'Standard';
    }

    private Boolean hardLimitReached() {
        return FeatureManagement.checkPackageIntegerValue('CustomFunctionHardCreditLimit') <=
            FeatureManagement.checkPackageIntegerValue('CustomFunctionCreditUsage');
    }

    private void resetCredits() {
        updateCustomFunctionCreditUsage(0);

        insert new CustomFunctionUsage__c(Name = String.valueOf(Date.today()), Year_Month__c = Date.today(), Credits__c = 0);
    }

    @Future
    private static void updateCustomFunctionCreditUsage(Integer usage) {
        FeatureManagement.setPackageIntegerValue('CustomFunctionCreditUsage', usage);
    }

    private List<CustomFunctionUsage__c> monthlyUsage() {
        // Protected system object, no security checks needed.
        return [
            SELECT Id
            FROM CustomFunctionUsage__c
            WHERE CALENDAR_YEAR(Year_Month__c) = :Date.today().year() AND CALENDAR_MONTH(Year_Month__c) = :Date.today().month()
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private void checkAPIKey() {
        Personal_Settings__c settings = Personal_Settings__c.getInstance();
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            throw new CopadoFunctionException(Label.Copado_API_Key_Required);
        }
    }

    private void checkCredential() {
        if (!isValidCredential) {
            throw new CopadoFunctionException(Label.Org_Credential_not_Validated);
        }
    }

    private Boolean isValidCredential() {
        Org__c credential = credential();

        return validatedRecently(credential) || validate(credential);
    }

    private Boolean validate(Org__c credential) {
        Boolean result;
        
        try {
            result = DeployAPI.validateOrg(credential.Id);
        } catch (Exception ex) {
            result = false;
        }
        
        return result;
    }

    private Org__c credential() {
        String sfdcOrgId = UserInfo.getOrganizationId() + '_' + UserInfo.getUserId();

        List<Org__c> credentials = [
            SELECT Disable_Validation__c, Oauth_Signature__c, Validated_Date__c
            FROM Org__c
            WHERE SFDC_Org_ID__c = :sfdcOrgId AND Username__c = :UserInfo.getUserName()
            WITH SECURITY_ENFORCED
        ];

        if (credentials.isEmpty()) {
            throw new CopadoFunctionException(Label.Credential_not_Found);
        }

        return credentials[0];
    }

    private Boolean validatedRecently(Org__c credential) {
        // TODO: Move validated date to custom setting
        return String.isNotBlank(credential.Oauth_Signature__c) && credential.Validated_Date__c >= Datetime.now().addDays(-1);
    }
  
    private void validateFunction() {
        if(function == null) {
            throw new CopadoFunctionException(Label.Function_not_Found + ': ' + apiName);
        }
    }

    private FunctionPayload payload() {
        return new FunctionPayload(function).parameters(parameters).options(options).validate(function.Parameters__c).resultId(result.Id);
    }

    private Result__c createResult() {
        Result__c result = new Result__c(
            JobStep__c = stepId,
            ParentId__c = contextId,
            Status__c = 'In Progress',
            Job_Type__c = apiName,
            Start_Time__c = Datetime.now(),
            ApexCallback__c = resultCallback,
            Function__c = function?.Id,
            Timeout__c = function?.Timeout__c,
            Function_Worker_Size__c = function?.Worker_Size__c
        );

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Result__c>{ result });
        result = (Result__c) decision.getRecords()[0];
        insert result;

        return result;
    }

    private CopadoFunctionException error(Exception ex) {
        CopadoFunctionException error = new CopadoFunctionException(ex.getMessage())
            .resultId(result?.Id)
            .contextId(contextId)
            .function(function)
            .stepId(stepId)
            .updateResult()
            .updateContext();

        return error;
    }
}