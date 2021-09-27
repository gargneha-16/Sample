public with sharing class PromotedUserStoriesSelector extends fflib_SObjectSelector {
    public SObjectType getSObjectType() {
        return Promoted_User_Story__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ Promoted_User_Story__c.User_Story__c, Promoted_User_Story__c.Promotion__c };
    }

    public List<Promoted_User_Story__c> byId(Set<Id> ids) {
        return (List<Promoted_User_Story__c>) selectSObjectsById(ids);
    }

    public List<Promoted_User_Story__c> byPromotionId(Set<Id> ids) {
        return (List<Promoted_User_Story__c>) Database.query(
            selectFields().setCondition(Promoted_User_Story__c.Promotion__c + ' IN :ids').toSOQL()
        );
    }

    public List<Promoted_User_Story__c> byPromotionIdWithFields(Set<Id> ids, Set<String> fields) {
        return new List<Promoted_User_Story__c>(
            (List<Promoted_User_Story__c>) Security.stripInaccessible(
                    AccessType.READABLE,
                    Database.query(newQueryFactory().setEnforceFLS(false).selectFields(fields).setCondition(Promoted_User_Story__c.Promotion__c + ' IN :ids').toSOQL())
                )
                .getRecords()
        );
    }

    public List<Promoted_User_Story__c> byBundleUSPromotions(Set<Id> promotionIds) {
        return (List<Promoted_User_Story__c>) Database.query(
            selectFields()
                .setCondition(
                    'Promotion__c IN :promotionIds AND Promotion__r.Back_Promotion__c = FALSE AND Promotion__r.Status__c = \'Completed\' AND User_Story__r.Is_Bundle__c = TRUE AND User_Story__r.RecordType.Name = \'Utility\''
                )
                .toSOQL()
        );
    }

    private fflib_QueryFactory selectFields() {
        return newQueryFactory()
                    .selectFields(new List<String> {
                        'User_Story__r.Name',
                        'Promotion__r.Destination_Environment__c',
                        'Promotion__r.Destination_Org_Credential__c',
                        'Promotion__r.Back_Promotion__c', 
                        'Promotion__r.Source_Org_Credential__c'
                    });
    }
}