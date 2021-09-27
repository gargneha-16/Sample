public with sharing class UISectionHelper {
    @AuraEnabled
    public static UISection__mdt fetchUISection(String platform, String uiSectionId) {
        try {
            UISection__mdt uiSection = [
                SELECT Component__c, Location__c, NamespacePrefix
                FROM UISection__mdt
                WHERE Extension_Package_Configuration__r.Platform__c = :platform AND Location__c = :uiSectionId
            ];//NOPMD
            return uiSection;
        } catch (Exception e) {
            throw new AuraHandledException(String.format(Label.UISectionNotFound, new List<Object>{ platform, uiSectionId, e.getMessage() }));
        }
    }
}