public with sharing class JobExecutionsSelector extends fflib_SObjectSelector {
    private String namespace = JobExecutionsSelector.class.getName().substringBefore('JobExecutionsSelector').removeEnd('.').toLowerCase();

    public SObjectType getSObjectType() {
        return JobExecution__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
            JobExecution__c.Id,
            JobExecution__c.Name,
            JobExecution__c.OwnerId,
            JobExecution__c.Status__c,
            JobExecution__c.ParentId__c,
            JobExecution__c.Promotion__c,
            JobExecution__c.Deployment__c,
            JobExecution__c.Callback__c,
            JobExecution__c.DataJson__c,
            JobExecution__c.VolumeOptions__c,
            JobExecution__c.ParentRecord_Id__c
        };
    }


    public JobExecution__c byId(Id recordId) {
        List<JobExecution__c> result = byId(new Set<Id>{ recordId });

        return (result.isEmpty() ? null : result[0]);
    }


    public List<JobExecution__c> byId(Set<Id> recordIds) {
        return (List<JobExecution__c>) selectSObjectsById(new Set<Id>(recordIds));
    }

    
    public JobExecution__c byPromotionId(Id promotionId) {
        fflib_QueryFactory query = newQueryFactory().setCondition(JobExecution__c.Promotion__c + ' = :promotionId');
        namespace = String.isNotBlank(namespace) ? namespace + '__' : namespace;
        new JobStepsSelector().addQueryFactorySubselect(query, namespace + 'JobSteps__r');

        List<JobExecution__c> result = (List<JobExecution__c>) Database.query(query.toSOQL());

        return (result.isEmpty() ? null : result[0]);
    }

    public JobExecution__c byDeploymentId(Id deploymentId) {
        fflib_QueryFactory query = newQueryFactory().setCondition(JobExecution__c.Deployment__c + ' = :deploymentId');
        namespace = String.isNotBlank(namespace) ? namespace + '__' : namespace;
        new JobStepsSelector().addQueryFactorySubselect(query, namespace + 'JobSteps__r');

        List<JobExecution__c> result = (List<JobExecution__c>) Database.query(query.toSOQL());

        return (result.isEmpty() ? null : result[0]);
    }
}