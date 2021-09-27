public with sharing class SetPropertyParents {
    private List<System_Property__c> records;
    private Map<Id, System_Property__c> old;

    // CONSTRUCTOR

    public SetPropertyParents(List<System_Property__c> records) {
        this.records = records;
    }

    public SetPropertyParents(List<System_Property__c> records, Map<Id, System_Property__c> old) {
        this(records);
        this.old = old;
    }

    // PUBLIC

    public void execute() {
        for (System_Property__c property : records) {
            updateParentLookups(property);
            if (String.isBlank(property.ParentId__c)) {
                property.addError(Label.ParentIdRequired);
            }
        }
    }

    // PRIVATE

    private void updateParentLookups(System_Property__c property) {
        property.ParentId__c = parentId(property);
        if (property.ParentId__c != property.User__c) {
            property.User__c = null;
        }
        if (property.ParentId__c != property.Environment__c) {
            property.Environment__c = null;
        }
        if (property.ParentId__c != property.Pipeline__c) {
            property.Pipeline__c = null;
        }
    }

    private Id parentId(System_Property__c property) {
        Id parentId;
        Boolean setFromLookup = false;
        System_Property__c oldRecord;
        if (Trigger.isInsert) {
            setFromLookup = property.User__c != null || property.Environment__c != null || property.Pipeline__c != null;
        } else if (Trigger.isUpdate) {
            oldRecord = old.get(property.Id);
            setFromLookup =
                property.User__c != oldRecord.User__c ||
                property.Environment__c != oldRecord.Environment__c ||
                property.Pipeline__c != oldRecord.Pipeline__c ||
                property.ParentId__c != oldRecord.ParentId__c;
        }
        if (setFromLookup) {
            parentId = fromLookup(property, oldRecord);
        } else {
            parentId = property.ParentId__c;
        }
        return parentId;
    }

    private Id fromLookup(System_Property__c property, System_Property__c oldRecord) {
        return new Map<Boolean, Id>{
                property.User__c != oldRecord?.User__c && String.isNotBlank(property.User__c) => property.User__c,
                property.Environment__c != oldRecord?.Environment__c && String.isNotBlank(property.Environment__c) => property.Environment__c,
                property.Pipeline__c != oldRecord?.Pipeline__c && String.isNotBlank(property.Pipeline__c) => property.Pipeline__c,
                property.ParentId__c != oldRecord?.ParentId__c && String.isNotBlank(property.ParentId__c) => property.ParentId__c
            }
            .get(true);
    }
}