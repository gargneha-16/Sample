public with sharing class TestsSelector extends fflib_SObjectSelector {
    private static final String BY_PARENT_CONDITION = 'User_Story__c = :parentId OR Feature__c = :parentId OR Application__c = :parentId';

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
            Test__c.Id,
            Test__c.Name,
            Test__c.Reference__c,
            Test__c.Category__c,
            Test__c.Tool__c,
            Test__c.User_Story__c,
            Test__c.Configuration__c
        };
    }

    public SObjectType getSObjectType() {
        return Test__c.sObjectType;
    }

    public List<Test__c> byIds(Set<Id> ids) {
        return (List<Test__c>) Database.query(newQueryFactory().setEnforceFLS(true).setCondition('Id IN :ids').toSOQL());
    }

    public List<Test__c> byParent(Id parentId) {
        return (List<Test__c>) Database.query(newQueryFactory().setEnforceFLS(true).setCondition(BY_PARENT_CONDITION).toSOQL());
    }

    public List<Test__c> byParentWithLatestResult(Id parentId) {
        fflib_QueryFactory query = newQueryFactory().setEnforceFLS(true).setCondition(BY_PARENT_CONDITION);
        String resultRelationship = Settings.ns + 'Results__r';

        query.subselectQuery(resultRelationship)
            .selectFields(new ResultsSelector().getSObjectFieldList())
            .addOrdering('Start_Time__c', fflib_QueryFactory.SortOrder.DESCENDING, true)
            .setLimit(1);
        
        return (List<Test__c>) Database.query(query.toSOQL());
    }
}