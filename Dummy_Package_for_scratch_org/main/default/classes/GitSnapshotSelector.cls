public with sharing class GitSnapshotSelector extends fflib_SObjectSelector {
    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ Git_Backup__c.Id };
    }

    public SObjectType getSObjectType() {
        return Git_Backup__c.sObjectType;
    }

    public List<Git_Backup__c> byCredentialRepoSnapshotOnly(Id orgId, Id repositoryId) {
        return Database.query(
            newQueryFactory()
                .setEnforceFLS(true)
                .setCondition('Org__c = :orgId AND Git_Repository__c = :repositoryId AND Git_Snapshot_Permissions__c != \'Allow Snapshots Only\'')
                .toSOQL()
        );
    }
}