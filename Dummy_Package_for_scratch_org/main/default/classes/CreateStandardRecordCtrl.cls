public with sharing class CreateStandardRecordCtrl {

    @AuraEnabled
    public static List<SupportedObject> getSupportedObjects() {
        List<SupportedObject> result = new List<SupportedObject>();

        try {
            for(SupportedObject__mdt supportedObject : new SupportedObjectsSelector().allObjects()) {
                result.add(new SupportedObject(supportedObject.SObject__r?.Label, supportedObject.SObject__r?.QualifiedApiName));
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static String getRecordBundle(List<Id> recordIds) {
        String result;

        try {
            result = CreateStandardRecords.serialize(new Set<Id>(recordIds));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    // INNER

    public class SupportedObject {
        @AuraEnabled
        public String label;
        
        @AuraEnabled
        public String value;

        public SupportedObject(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}