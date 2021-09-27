public with sharing class DeleteSensitiveProperties implements Queueable, Database.AllowsCallouts {
    
    private List<System_Property__c> propertiesToBeDeleted = new List<System_Property__c>();
    
    // CONSTRUCTOR

    public DeleteSensitiveProperties(List<System_Property__c> records) {
        propertiesToBeDeleted = filterSensitiveRecords(records);
    }


    // PUBLIC

    public void execute() {
        if(!propertiesToBeDeleted.isEmpty()) {
            System.enqueueJob(this);
        }

    }


    public void execute(QueueableContext context) {
        CustomMetadata.deleteMetadata('CustomMetadata', sensitivePropertyNames());
    }


    // PRIVATE


    private List<System_Property__c> filterSensitiveRecords(List<System_Property__c> properties) {
        List<System_Property__c> result = new List<System_Property__c>();

        for(System_Property__c property : properties) {
            if(property.Is_Sensitive__c) {
                result.add(property);
            }
        }

        return result;
    }

    private List<String> sensitivePropertyNames() {
        List<String> result = new List<String>();

        for(System_Property__c property : propertiesToBeDeleted) {
            String metadataName = Settings.ns + 'SensitiveProperty__mdt.' + property.Id;

            result.add(metadataName);
        }

        return result;
    }
}