public with sharing class ResultMonitorLWCHandler {
    private static Id recordId;
    private static String objectName;
    private static String fieldName;
    private static String templateName;
    private static String jobExecutionId;


    // PUBLIC

    @AuraEnabled(cacheable=false)
    public static ResultStatusDetail result(Id recId, String objectApiName, String fieldApiName) {
        recordId = recId != null ? recId : null;
        objectName = getObjectApiName(objectApiName);
        fieldName = String.isNotBlank(fieldApiName) ? fieldApiName : '';

        recordDetail();
        return getResultStatusDetail();
    }


    // PRIVATE

    private static String getObjectApiName(String objectApiName) {
        return recordId != null ? recordId.getSObjectType().getDescribe().getName() : ((SObject) Type.forName(objectApiName).newInstance()).getSObjectType().getDescribe().getName();
    }

    private static void recordDetail() {
        String secureId = String.escapeSingleQuotes(recordId);
        String whereClause = 'Id = :secureId';

        String query = String.format(
            'SELECT {0} FROM {1} WHERE {2} LIMIT 1',
            new List<String>{ fieldName, objectName, whereClause }
        );

        jobExecutionId = (String) Database.query(query)[0]?.get(fieldName);
    } 

    public static ResultStatusDetail getResultStatusDetail() {
        ResultStatusDetail result = new ResultStatusDetail();
        result.jobExecutionId = jobExecutionId;
        result.jobExecutionObjectApiName = SObjectType.JobExecution__c.getLocalName();
        result.resultDetails = populateResultDetails();
        result.mainTitle = templateName;

        return result;
    }

    private static List<ResultStatusDetail.ResultDetail> populateResultDetails() {
        List<ResultStatusDetail.ResultDetail> resultDetails = new List<ResultStatusDetail.ResultDetail>();
        for(JobStep__c jobStep : jobSteps()) {
            ResultStatusDetail.ResultDetail detail = new ResultStatusDetail.ResultDetail();
            detail.jobStepId = jobStep.Id;
            detail.jobStepObjectApiName = SObjectType.JobStep__c.getLocalName();
            detail.jobStepLabel = jobStep.Name;
            detail.resultId = jobStep.Result__c != null ? jobStep.Result__r.Id : null;
            detail.resultStatus = jobStep.Result__c != null ? jobStep.Result__r.Status__c : 'Not Started';
            detail.resultValue = jobStep.Result__c != null ? jobStep.Result__r.Name : '';
            detail.resultLabel = Label.View_result;
            detail.resultObjectApiName = SObjectType.Result__c.getLocalName();
            resultDetails.add(detail);

            if(String.isBlank(templateName)) {
                templateName = jobStep.JobExecution__r.Template__r.Name;
            }
        }
        return resultDetails;
    }

    private static List<JobStep__c> jobSteps() {
        return [SELECT Id,
                        Name,
                        Result__c,
                        Result__r.Name, 
                        Result__r.Status__c,
                        Result__r.Progress_Status__c,
                        JobExecution__r.Template__r.Name
                FROM JobStep__c 
                WHERE JobExecution__c != NULL AND JobExecution__c = :jobExecutionId
                WITH SECURITY_ENFORCED 
                ORDER BY JobExecution__r.CreatedDate, Order__c];
    }
}