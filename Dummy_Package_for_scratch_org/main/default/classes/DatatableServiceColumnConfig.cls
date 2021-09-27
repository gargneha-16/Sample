/**
 * This class is used as a wrapper by DatatableServiceCtrl
 */
// Note: These parameters are returned to a javascript controller so they need to be public
@SuppressWarnings('PMD.ExcessivePublicCount')
public with sharing class DatatableServiceColumnConfig {
    @AuraEnabled
    public String actions;
    @AuraEnabled
    public CellAttributes cellAttributes;
    @AuraEnabled
    public Boolean editable;
    @AuraEnabled
    public String fieldName;
    @AuraEnabled
    public Integer fixedWidth;
    @AuraEnabled
    public Boolean hideDefaultActions;
    @AuraEnabled
    public String iconName;
    @AuraEnabled
    public String initialWidth;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Boolean searchable;
    @AuraEnabled
    public Boolean filterable;
    @AuraEnabled
    public Boolean sortable;
    @AuraEnabled
    public String type;
    @AuraEnabled
    public TypeAttributes typeAttributes;
    @AuraEnabled
    public Boolean wrapText;

    // Documentation states that Date and Datetime fields are no inline editable but it is not true
    // Types of number are not editable since they are passed as text and causing an exception
    // But enabled and tested for DOUBLE and it is working fine, hence enabled DOUBLE
    private final static Set<DisplayType> NON_EDITABLE_TYPES = new Set<DisplayType>{ DisplayType.ADDRESS, DisplayType.INTEGER, DisplayType.LONG };

    // CTOR

    public DatatableServiceColumnConfig(FieldSetMember field, Boolean editable, Boolean searchable) {
        this.editable = editable == null ? false : editable;
        this.searchable = searchable == null ? false : searchable;
        initColumnConfig(field);
    }

    // PUBLIC

    public DatatableServiceColumnConfig hideDefaultActions(Boolean hideDefaultActions) {
        this.hideDefaultActions = hideDefaultActions == null ? false : hideDefaultActions;
        return this;
    }

    public DatatableServiceColumnConfig sortable(Boolean sortable) {
        this.sortable = sortable == null ? false : sortable;
        return this;
    }

    public DatatableServiceColumnConfig filterable(Boolean filterable) {
        this.filterable = filterable == null ? false : filterable;
        return this;
    }

    // PRIVATE

    private void initColumnConfig(FieldSetMember field) {
        String fieldPath = getFieldName(field);
        label = fieldPath.contains('.') ? getRelationalLabel(fieldPath) : field.getLabel();
        DisplayType fieldType = field.getType();
        if (fieldType == DisplayType.REFERENCE) {
            if (fieldPath.endsWith(DatatableConstants.CUSTOM_FIELD_PATH_END)) {
                fieldPath = fieldPath.replace(DatatableConstants.CUSTOM_FIELD_PATH_END, DatatableConstants.CUSTOM_REFERENCE_FIELD_NAME);
            } else if (fieldPath.endsWith(DatatableConstants.ID)) {
                // Trick to no to replace other possible appearances of 'Id' in the field name
                fieldPath = fieldPath + DatatableConstants.DOUBLE_UNDERSCORE;
                fieldPath = fieldPath.replace(
                    DatatableConstants.ID + DatatableConstants.DOUBLE_UNDERSCORE,
                    DatatableConstants.STANDARD_REFERENCE_FIELD_NAME
                );
            }
        }

        // TODO: Handle other non-name fields like CaseNumber
        if (fieldPath == DatatableConstants.NAME || fieldPath.endsWith(DatatableConstants.STANDARD_REFERENCE_FIELD_NAME)) {
            fieldName = fieldPath.replace(DatatableConstants.NAME, DatatableConstants.LINKNAME);
            type = DatatableConstants.FIELDTYPE_URL;
            editable = false;
        } else {
            fieldName = fieldPath;
            type = DatatableConstants.FORMATTING_TYPE_BY_FIELD_TYPE.get(fieldType);
            // NOTE: By making a column editable, the show-row-number-column attribute is always true and the number column is displayed
            editable = editable && isUpdateable(field) && !NON_EDITABLE_TYPES.contains(fieldType);
        }

        if (type == DatatableConstants.FIELDTYPE_URL) {
            cellAttributes = new CellAttributes();
            typeAttributes = new TypeAttributes(fieldPath, field);
        } else {
            typeAttributes = new TypeAttributes(fieldType);
        }

        if (type == DatatableConstants.FIELDTYPE_BOOLEAN) {
            searchable = false;
        }
    }

    private String getRelationalLabel(String fieldPath) {
        // TODO: currently using field sets, only one parent level is allowed,
        // but this is not really accurate, it should be a recursive method (since there may be multiple levels)
        // TODO: retrieving proper labels for each relationship until the last field, otherwise there will be an
        // issue if api name does not correspond to label

        String result = fieldPath.replace(DatatableConstants.REFERENCE_FIELD_PATH_END, '')
            .replace(DatatableConstants.CUSTOM_FIELD_PATH_END, '')
            .replace('.', DatatableConstants.SPACE)
            .replace(DatatableConstants.UNDERSCORE, DatatableConstants.SPACE);
        result = String.join(result.splitByCharacterTypeCamelCase(), DatatableConstants.SPACE);
        return result;
    }

    private Boolean isUpdateable(FieldSetMember field) {
        return field.getSObjectField().getDescribe().isUpdateable();
    }

    private String getFieldName(FieldSetMember field) {
        return field.getSObjectField().getDescribe().getName();
    }

    // INNER

    private with sharing class TypeAttributes {
        @AuraEnabled
        public Label label;
        @AuraEnabled
        public String target;
        @AuraEnabled
        public ToolTip tooltip;
        @AuraEnabled
        public String fieldType;
        @AuraEnabled
        public String fieldPath;
        @AuraEnabled
        public Boolean isUpdateable;

        // CTOR

        public TypeAttributes(DisplayType type) {
            fieldType = String.valueOf(type);
        }

        public TypeAttributes(String fieldName, FieldSetMember field) {
            label = new Label(fieldName);
            target = DatatableConstants.TARGET_BLANK;
            tooltip = new ToolTip(fieldName);
            fieldType = String.valueOf(field.getType());
            DescribeFieldResult fieldDescribe = field.getSObjectField().getDescribe();
            fieldPath = fieldDescribe.getName();
            isUpdateable = fieldDescribe.isUpdateable();
        }
    }

    private with sharing class Label {
        @AuraEnabled
        public String fieldName;

        // CTOR

        public Label(String fieldName) {
            this.fieldName = fieldName;
        }
    }

    private with sharing class ToolTip {
        @AuraEnabled
        public String fieldName;

        // CTOR

        public ToolTip(String fieldName) {
            this.fieldName = fieldName;
        }
    }

    private with sharing class CellAttributes {
        @AuraEnabled
        public String alignment;

        // CTOR

        public CellAttributes() {
            alignment = DatatableConstants.ALIGNMENT_LEFT;
        }
    }
}