public with sharing class ResultStatusDetail {
    @AuraEnabled public String mainTitle { get; set; }
    @AuraEnabled public String jobExecutionId { get; set; }
    @AuraEnabled public String jobExecutionObjectApiName { get; set; }
    @AuraEnabled public List<ResultDetail> resultDetails { get; set; }

    public class ResultDetail {
        @AuraEnabled public Id jobStepId { get; set; }
        @AuraEnabled public String jobStepObjectApiName { get; set; }
        @AuraEnabled public String jobStepLabel { get; set; }
        @AuraEnabled public Id resultId { get; set; }
        @AuraEnabled public String resultStatus { get; set; }
        @AuraEnabled public String resultValue { get; set; }
        @AuraEnabled public String resultLabel { get; set; }
        @AuraEnabled public String resultObjectApiName { get; set; }
    }
}