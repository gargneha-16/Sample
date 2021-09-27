public with sharing class FeaturesSelector extends fflib_SObjectSelector {
    // CTOR

    public FeaturesSelector() {
        this(true, true);
    }

    public FeaturesSelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS, false);
    }

    // PUBLIC

    public SObjectType getSObjectType() {
        return Application_Feature__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ Application_Feature__c.Application__c };
    }

    public List<Application_Feature__c> byIds(Set<Id> recordIds) {
        return selectSObjectsById(recordIds);
    }
}