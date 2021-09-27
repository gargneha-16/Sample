public with sharing class JobTemplatesSelector extends fflib_SObjectSelector {

    public SObjectType getSObjectType() {
        return JobTemplate__c.sObjectType;
    }


    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
            JobTemplate__c.Id,
            JobTemplate__c.Name,
            JobTemplate__c.Type__c,
            JobTemplate__c.ApiName__c,
            JobTemplate__c.VolumeOptions__c
        };
    }


    public List<JobTemplate__c> byId(Set<Id> recordIds) {
        return (List<JobTemplate__c>) selectSObjectsById(recordIds);
    }


    public List<JobTemplate__c> byName(String name) {
        return byName(new Set<String> { name });
    }


    public List<JobTemplate__c> byName(Set<String> names) {
        fflib_QueryFactory query = newQueryFactory().setCondition(JobTemplate__c.ApiName__c + ' IN :names');

        String stepRelationship = Settings.ns + 'JobSteps__r';
        query.subselectQuery(stepRelationship)
                .selectFields(new JobStepsSelector().getSObjectFieldList()).setOrdering('Order__c', fflib_QueryFactory.SortOrder.ASCENDING);

        return (List<JobTemplate__c>) Database.query(query.toSOQL());
    }
}