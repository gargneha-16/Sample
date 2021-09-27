public with sharing class DatatableQueryConfiguration {
    @AuraEnabled
    public String selectFieldSet { get; set; }
    @AuraEnabled
    public String fromObject { get; set; }
    @AuraEnabled
    public String relationshipField {
        get {
            if (relationshipField != null) {
                relationshipField = String.escapeSingleQuotes(relationshipField);
            }
            return relationshipField;
        }
        set;
    }
    @AuraEnabled
    public Id parentId {
        get {
            if (parentId != null) {
                parentId = String.escapeSingleQuotes(parentId);
            }
            return parentId;
        }
        set;
    }
    @AuraEnabled
    public String orderBy { get; set; }
    @AuraEnabled
    public Integer recordsLimit { get; set; }
    @AuraEnabled
    public Integer recordsOffset { get; set; }

    // PUBLIC

    public String getFormattedQuery() {
        String query = String.format(DatatableConstants.QUERY_TEMPLATE, getParameters());
        return query;
    }

    // PRIVATE

    private List<Object> getParameters() {
        relationshipField = (String.isBlank(relationshipField)) ? getDefaultRelationshipField() : relationshipField;
        return new List<Object>{ getSelectFields(), fromObject, relationshipField, parentId, orderBy, recordsLimit, recordsOffset };
    }

    private String getSelectFields() {
        Set<String> fields = new Set<String>();

        for (FieldSetMember field : getFieldSetFields()) {
            String fieldToAdd = getFieldName(field);
            if (field.getType() == DisplayType.REFERENCE) {
                if (fieldToAdd.endsWith(DatatableConstants.CUSTOM_FIELD_PATH_END)) {
                    fieldToAdd = fieldToAdd.replace(DatatableConstants.CUSTOM_FIELD_PATH_END, DatatableConstants.CUSTOM_REFERENCE_FIELD_NAME);
                } else if (fieldToAdd.endsWith(DatatableConstants.ID)) {
                    // Trick to no to replace other possible appearances of 'Id' in the field name
                    fieldToAdd = fieldToAdd + DatatableConstants.DOUBLE_UNDERSCORE;
                    fieldToAdd = fieldToAdd.replace(
                        DatatableConstants.ID + DatatableConstants.DOUBLE_UNDERSCORE,
                        DatatableConstants.STANDARD_REFERENCE_FIELD_NAME
                    );
                }
            }
            fields.add(fieldToAdd);
        }
        return String.join(new List<String>(fields), DatatableConstants.COMMA);
    }

    private List<FieldSetMember> getFieldSetFields() {
        return fflib_SObjectDescribe.getDescribe(fromObject).getFieldSets().get(selectFieldSet).getFields();
    }

    private String getFieldName(FieldSetMember field) {
        return field.getSObjectField().getDescribe().getName();
    }

    private String getDefaultRelationshipField() {
        List<SObjectField> sObjectFields = fflib_SObjectDescribe.getDescribe(fromObject).getFieldsMap().values();
        String parentObject = parentId.getSObjectType().getDescribe().getName();

        for (SObjectField field : sObjectFields) {
            DescribeFieldResult fieldDescribe = field.getDescribe();
            String fieldType = fieldDescribe.getType().name();
            if (fieldType == DatatableConstants.FIELDTYPE_REFERENCE && parentObject == fieldDescribe.getReferenceTo()[0].getDescribe().getName()) {
                return fieldDescribe.getName();
            }
        }

        throw new InvalidRelationshipException(Label.Invalid_Relationship_Error);
    }

    // INNER

    private class InvalidRelationshipException extends Exception {
    }
}