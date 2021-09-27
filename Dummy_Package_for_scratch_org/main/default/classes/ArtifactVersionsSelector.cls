public with sharing class ArtifactVersionsSelector extends fflib_SObjectSelector {
    // CONSTRUCTOR

    public ArtifactVersionsSelector() {
        this(true, true);
    }

    public ArtifactVersionsSelector(Boolean enforceCRUD, Boolean enforceFLS) {
        super(false, enforceCRUD, enforceFLS);
    }

    // PUBLIC

    public Schema.SObjectType getSObjectType() {
        return Artifact_Version__c.sObjectType;
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{ Artifact_Version__c.Name,
            Artifact_Version__c.User_Story__c,
            Artifact_Version__c.Status__c };
    }

    public List<Artifact_Version__c> byIds(Set<Id> ids) {
        return selectSObjectsById(ids);
    }

    public List<Artifact_Version__c> byStoryIdWithBundledStories(Set<Id> stories) {
        fflib_QueryFactory query = newQueryFactory().setCondition(Artifact_Version__c.User_Story__c + ' IN :stories');

        new BundledStorySelector().addQueryFactorySubselect(query);

        return Database.query(query.toSOQL());
    }
}