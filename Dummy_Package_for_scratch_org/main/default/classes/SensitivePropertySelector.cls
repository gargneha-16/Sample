public with sharing class SensitivePropertySelector extends fflib_SObjectSelector {

    private static List<SensitiveProperty__mdt> mock = new List<SensitiveProperty__mdt>();
    
    public Schema.SObjectType getSObjectType() {
        return SensitiveProperty__mdt.SObjectType;
    }


    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            SensitiveProperty__mdt.Id,
            SensitiveProperty__mdt.Value__c,
            SensitiveProperty__mdt.DeveloperName
        };
    }


    public List<SensitiveProperty__mdt> byName(Set<Id> systemPropertyIds) {
        return (Test.isRunningTest()) ? mock : 
                (List<SensitiveProperty__mdt>) Database.query( newQueryFactory()
                                                                .setCondition(SensitiveProperty__mdt.DeveloperName + ' IN :systemPropertyIds')
                                                                .toSOQL() );
    }
    
    
    public static void mock(List<SensitiveProperty__mdt> properties) {
        mock = properties;
    }
}