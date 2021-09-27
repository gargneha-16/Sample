public virtual with sharing class CopadoFunctionException extends Exception {
    private Id stepId;
    private String contextId;
    private Function__c function;
    public String resultId { get; private set; }

    public CopadoFunctionException function(Function__c function) {
        this.function = function;
        return this;
    }

    public CopadoFunctionException resultId(String resultId) {
        this.resultId = resultId;
        return this;
    }

    public CopadoFunctionException stepId(Id stepId) {
        this.stepId = stepId;
        return this;
    }

    public CopadoFunctionException contextId(String contextId) {
        this.contextId = contextId;
        return this;
    }

    public CopadoFunctionException updateResult() {
        resultId = String.isBlank(resultId) ? getChildResult() : resultId;

        if (String.isBlank(resultId)) {
            resultId = createResult();
        } else {
            // needed for ease of internal troubleshooting when an error occurs in a subscriber org.
            System.debug(LoggingLevel.ERROR, 'error: ' + this.getMessage() + ': ' + this.getStackTraceString());
            update Security.stripInaccessible(
                    AccessType.UPDATABLE,
                    new List<Result__c>{
                        new Result__c(
                            Id = resultId,
                            End_Time__c = Datetime.now(),
                            Status__c = 'Failed',
                            JobStep__c = stepId,
                            Progress_Status__c = Label.Error,
                            Error_Message__c = this.getMessage()
                        )
                    }
                )
                .getRecords();
        }

        return this;
    }

    private Id getChildResult() {
        Id result = null;

        if (String.isNotBlank(contextId)) {
            result = [SELECT Id FROM Result__c WHERE ParentId__c = :contextId WITH SECURITY_ENFORCED ORDER BY Start_Time__c DESC LIMIT 1]?.Id;
        }

        return result;
    }

    public CopadoFunctionException updateContext() {
        if (objectType() == 'Deployment_Job__c') {
            Deployment_Job__c job = job();
            update Security.stripInaccessible(AccessType.UPDATABLE, new List<Deployment_Job__c>{ job }).getRecords();
            Result__c result = [SELECT Deployment__c FROM Result__c WHERE Id = :resultId WITH SECURITY_ENFORCED];

            result.Deployment__c = job.Step__r.Deployment__c;
            update Security.stripInaccessible(AccessType.UPDATABLE, new List<Result__c>{ result }).getRecords();
        }

        new HandleBackendResponse().resultCallback(function, resultId, 'Error');

        return this;
    }

    private Deployment_Job__c job() {
        Deployment_Job__c job = [
            SELECT Status__c, Last_Result__c, Step__r.Deployment__c
            FROM Deployment_Job__c
            WHERE Id = :contextId
            WITH SECURITY_ENFORCED
        ];
        job.Status__c = 'Failed';
        job.Last_Result__c = resultId;

        return job;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private Id createResult() {
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<Result__c>{ result() });
        Result__c result = (Result__c) decision.getRecords()[0];
        insert result;

        return result.Id;
    }

    private Result__c result() {
        return new Result__c(
            Job_Type__c = function != null ? function.API_Name__c : SObjectType.Function__c.getLabel(),
            Start_Time__c = Datetime.now(),
            End_Time__c = Datetime.now(),
            Status__c = 'Failed',
            Function__c = function?.Id,
            ParentId__c = contextId,
            Progress_Status__c = Label.Error,
            Error_Message__c = this.getMessage()
        );
    }

    private String objectType() {
        return String.isNotBlank(contextId) ? Id.valueOf(contextId).getSObjectType().getDescribe().getLocalName() : '';
    }
}