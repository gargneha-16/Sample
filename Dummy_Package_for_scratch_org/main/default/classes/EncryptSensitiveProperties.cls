public with sharing class EncryptSensitiveProperties implements Queueable, Database.AllowsCallouts {
    private static final String NAMESPACE = Settings.ns;
    private List<MetadataService.Metadata> sensitivePropertiesToInsert = new List<MetadataService.Metadata>();
    private List<MetadataService.Metadata> sensitivePropertiesToUpdate = new List<MetadataService.Metadata>();

    private List<String> propertiesToDelete = new List<String>();
    List<System_Property__c> propertiesToUpdate = new List<System_Property__c>();
    private List<System_Property__c> blankSystemPropertiesToBeDeleted = new List<System_Property__c>();

    // CONSTRUCTOR

    public EncryptSensitiveProperties(List<System_Property__c> records) {
        this.sensitivePropertiesToInsert = filterSensitiveRecords(records);
    }



    public EncryptSensitiveProperties(List<System_Property__c> records, Map<Id, System_Property__c> oldMap) {
        setPropertiesToInsertAndDelete(records, oldMap);
    }



    // PUBLIC

    public void execute() {
        fflib_SObjectDomain.getTriggerEvent(SystemProperties.class).disableAll();

        if(!blankSystemPropertiesToBeDeleted.isEmpty()) {
            populateValueFromMetadata();
        }

        update propertiesToUpdate;

        fflib_SObjectDomain.getTriggerEvent(SystemProperties.class).enableAll();

        System.enqueueJob(this);
    }

    public void execute(QueueableContext context) {

        if(!sensitivePropertiesToInsert.isEmpty()) {
            CustomMetadata.create(sensitivePropertiesToInsert);
        }
        
        if(!sensitivePropertiesToUpdate.isEmpty()) {
            CustomMetadata.updateMetadata(sensitivePropertiesToUpdate);
        }
        
        if(!propertiesToDelete.isEmpty()) {
            CustomMetadata.deleteMetadata('CustomMetadata', propertiesToDelete);
        }
    }



    // PRIVATE

    private void populateValueFromMetadata() {
        Map<String, SensitiveProperty__mdt> sensitivePropertyById = groupById(selectPropertyByIds(blankSystemPropertiesToBeDeleted));
        
        for(System_Property__c property : blankSystemPropertiesToBeDeleted) {
            if(sensitivePropertyById.containsKey(property.Id)) {
                property.Value__c = DeployAPI.decryptAPIKey(sensitivePropertyById.get(property.Id).Value__c);
            }
        }
    }



    private Map<String, SensitiveProperty__mdt> groupById(List<SensitiveProperty__mdt> sensitiveProperties) {
        Map<String, SensitiveProperty__mdt> result = new Map<String, SensitiveProperty__mdt>();

        for(SensitiveProperty__mdt sensitiveProperty : sensitiveProperties) {
            result.put(sensitiveProperty.DeveloperName, sensitiveProperty);
        }

        return result;
    }



    private List<SensitiveProperty__mdt> selectPropertyByIds(List<System_Property__c> properties) {
        Set<Id> systemPropertyIds = new Map<Id, System_Property__c>(properties).keySet();

        return new SensitivePropertySelector().byName(systemPropertyIds);
    }



    private List<MetadataService.Metadata> filterSensitiveRecords(List<System_Property__c> properties) {
        List<MetadataService.Metadata> result = new List<MetadataService.Metadata>();

        for(System_Property__c property : properties) {
            if(property.Is_Sensitive__c) {
                result.add( asSensitiveProperty(property));
            }
        }

        return result;
    }


    private void setPropertiesToInsertAndDelete(List<System_Property__c> properties, Map<Id, System_Property__c> oldMap) {

        for(System_Property__c property : properties) {
            System_Property__c oldProperty = oldMap.get(property.Id);

            if(property.Is_Sensitive__c && !oldProperty.Is_Sensitive__c) {
                this.sensitivePropertiesToInsert.add( asSensitiveProperty(property));

            } else if (property.Is_Sensitive__c && property.Value__c != oldProperty.Value__c) {
                this.sensitivePropertiesToUpdate.add(asSensitiveProperty(property));
            } else if (!property.Is_Sensitive__c && isChanged(property, oldProperty)) {

                String metadataName = NAMESPACE + 'SensitiveProperty__mdt.' + property.Id;
                this.propertiesToDelete.add(metadataName);

                if(String.isBlank(property.Value__c)) {
                    blankSystemPropertiesToBeDeleted.add(property);
                }
            }
        }
    }



    private Boolean isChanged(System_Property__c property, System_Property__c oldProperty) {
        return (property.Is_Sensitive__c != oldProperty.Is_Sensitive__c || property.Value__c != oldProperty.Value__c);
    }



    private MetadataService.CustomMetadata asSensitiveProperty(System_Property__c property) {
        MetadataService.CustomMetadata result = new MetadataService.CustomMetadata();
        result.fullName = NAMESPACE + 'SensitiveProperty__mdt.' + property.Id;
        result.label = property.Name;
        result.values = new List<MetadataService.CustomMetadataValue>{
                new MetadataService.CustomMetadataValue(NAMESPACE + 'Value__c', DeployAPI.encryptAPIKey(property.Value__c)) 
            };

        if(Trigger.isAfter && Trigger.isInsert) {
            propertiesToUpdate.add(new System_Property__c(Id = property.Id, Value__c = null));

        } else {

            property.Value__c = null;
        }
        
        return result;
    }
}