public with sharing class JobStepsSelector extends fflib_SObjectSelector {
    // TODO: Remove this comment

    public SObjectType getSObjectType() {
        return JobStep__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
            JobStep__c.Id,
            JobStep__c.Name,
            JobStep__c.Type__c,
            JobStep__c.Order__c,
            JobStep__c.Result__c,
            JobStep__c.Status__c,
            JobStep__c.ApiName__c,
            JobStep__c.ConfigJson__c,
            JobStep__c.CustomType__c,
            JobStep__c.JobTemplate__c,
            JobStep__c.JobExecution__c,
            JobStep__c.ResultDataJson__c,
            JobStep__c.ExecutionSequence__c
        };
    }

    public JobStep__c byId(Id recordId) {
        return byId(new Set<Id>{ recordId }).get(0);
    }

    public List<JobStep__c> byId(Set<Id> recordIds) {
        return (List<JobStep__c>) selectSObjectsById(new Set<Id>(recordIds));
    }

    public List<JobStep__c> byJob(Id jobId) {
        fflib_QueryFactory query = newQueryFactory()
            .setCondition('JobExecution__c = :jobId')
            .setOrdering('Order__c', fflib_QueryFactory.SortOrder.ASCENDING);

        return Database.query(query.toSOQL());
    }

    public List<JobStep__c> byUserStoryId(Set<Id> userStoryIds) {
        fflib_QueryFactory query = newQueryFactory()
            .setCondition('UserStory__c IN :userStoryIds')
            .setOrdering('Order__c', fflib_QueryFactory.SortOrder.ASCENDING)
            .addOrdering('UserStory__r.Name', fflib_QueryFactory.SortOrder.ASCENDING);

        return Database.query(query.toSOQL());
    }

    public JobStep__c byResultId(Id resultId) {
        fflib_QueryFactory query = newQueryFactory().setCondition('Result__c = :resultId').setLimit(1);

        List<JobStep__c> result = Database.query(query.toSOQL());

        return (result.isEmpty() ? null : result[0]);
    }

    public List<JobStep__c> byTemplate(Id templateId) {
        fflib_QueryFactory query = newQueryFactory()
            .setCondition('JobTemplate__c = :templateId')
            .setOrdering('Order__c', fflib_QueryFactory.SortOrder.ASCENDING);

        return Database.query(query.toSOQL());
    }

    public JobStep__c getNext(Id jobId) {
        fflib_QueryFactory query = newQueryFactory()
            .setCondition('JobExecution__c = :jobId AND Status__c = \'Pending\'')
            .setOrdering('Order__c', fflib_QueryFactory.SortOrder.ASCENDING)
            .setLimit(1);

        List<JobStep__c> result = Database.query(query.toSOQL());

        return (result.isEmpty() ? null : result[0]);
    }
}