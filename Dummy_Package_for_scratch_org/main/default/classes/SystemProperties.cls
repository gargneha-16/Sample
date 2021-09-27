public with sharing class SystemProperties extends fflib_SObjectDomain {
    // CONSTRUCTOR

    public SystemProperties(List<System_Property__c> records) {
        super(records);
    }

    // PUBLIC

    public override void onAfterInsert() {
        new EncryptSensitiveProperties(records).execute();
    }



    public override void onAfterDelete() {
        new DeleteSensitiveProperties(records).execute();
    }



    public override void onBeforeInsert() {
        new SetPropertyParents(records).execute();
    }

    public override void onBeforeUpdate(Map<Id, SObject> old) {
        new SetPropertyParents(records, (Map<Id, System_Property__c>) old).execute();


        new EncryptSensitiveProperties(records, (Map<Id, System_Property__c>) old).execute();
    }

    // INNER

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> records) {
            return new SystemProperties(records);
        }
    }
}