public with sharing class SystemPropertiesSelector extends fflib_SObjectSelector {

    private static List<System_Property__c> mock = new List<System_Property__c>();
    
    public Schema.SObjectType getSObjectType() {
        return System_Property__c.SObjectType;
    }


    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            System_Property__c.Id,
            System_Property__c.UID__c,
            System_Property__c.User__c,
            System_Property__c.Value__c,
            System_Property__c.API_Name__c,
            System_Property__c.Pipeline__c,
            System_Property__c.ParentId__c,
            System_Property__c.Is_Sensitive__c,
            System_Property__c.Environment__c
        };
    }


    public System_Property__c byUID(String uId) {
        return byUID(new Set<String> { uId }).get(uId);
    }


    public Map<String, System_Property__c> byUID(Set<String> uIds) {
        List<System_Property__c> properties = (List<System_Property__c>) Database.query( newQueryFactory()
                                                                                .setCondition(System_Property__c.UID__c + ' IN :uIds')
                                                                                .toSOQL() );

        return whithDecryptedValues(properties);
    }
    

    // PRIVATE

    private Map<String, System_Property__c> whithDecryptedValues(List<System_Property__c> properties) {
        Map<String, System_Property__c> result = new Map<String, System_Property__c>();

        Set<Id> systemPropertyIds = new Map<Id, System_Property__c>(properties).keySet();
        Map<String, SensitiveProperty__mdt> sensitivePropertyByName = groupById( new SensitivePropertySelector().byName(systemPropertyIds) );

        for(System_Property__c property : properties) {
            if(sensitivePropertyByName.containsKey(property.Id)) {
                String value = sensitivePropertyByName.get(property.Id).Value__c;
                property.Value__c = DeployAPI.decryptAPIKey(value);
            }

            result.put(property.UID__c, property);
        }

        return result;
    }


    private Map<String, SensitiveProperty__mdt> groupById(List<SensitiveProperty__mdt> sensitiveProperties) {
        Map<String, SensitiveProperty__mdt> result = new Map<String, SensitiveProperty__mdt>();

        for(SensitiveProperty__mdt sensitiveProperty : sensitiveProperties) {
            result.put(sensitiveProperty.DeveloperName, sensitiveProperty);
        }

        return result;
    }
}