// Note: These parameters are returned to a javascript controller so they need to be public
@SuppressWarnings('PMD.ExcessivePublicCount')
public with sharing class FilterComponentController {
    
    
    @AuraEnabled
    public static List<FieldListWrapper> getFields(){
        List<FieldListWrapper> listOfFieldWrapper = new List<FieldListWrapper>();
        Map <String, Schema.SObjectField> mapOfDesiredObject = fflib_SObjectDescribe.getDescribe(FilterConstant.USER_STORY).getFieldsMap();
        for(Schema.SObjectField sObjectfield : mapOfDesiredObject.Values())
        {
            Schema.describefieldresult dfield = sObjectfield.getDescribe();
            FieldListWrapper fieldWrapperObj = new FieldListWrapper( dfield);
            fieldWrapperObj.createFieldList(dfield,mapOfDesiredObject);
            listOfFieldWrapper.add(fieldWrapperObj);
        }
        return listOfFieldWrapper;
    }

    @AuraEnabled
    public static List<User_Story__c> filterUserStoryRecord(String config){
        FilterConfiguration configuration =(FilterConfiguration) System.JSON.deserialize(config, FilterConfiguration.class);
        String fields = getSelectFields(configuration.selectFieldSet);
        List<User_Story__c> userStoryList = new List<User_Story__c>();
        List<FieldOperatorValueWrapper> listOfFieldOperatorValueWrapper = (List<FieldOperatorValueWrapper>) System.JSON.deserialize(configuration.filterString, List<FieldOperatorValueWrapper>.class);
        String currentLoggedInuser = UserInfo.getUserId() ;
        String query;
        if(configuration.ownerString == 'My User Stories'){
            query = 'SELECT '+String.escapeSingleQuotes(fields)+ ' FROM User_Story__c WHERE Sprint__c = \''+String.escapeSingleQuotes(configuration.recordId )+'\' AND ownerid=\''+String.escapeSingleQuotes(currentLoggedInuser )+'\'';    
        }else{
            query = 'SELECT '+ +String.escapeSingleQuotes(fields) +' FROM User_Story__c  WHERE Sprint__c = \''+String.escapeSingleQuotes(configuration.recordId )+'\'';
        }
        List<String> listofWhereClause = new List<String>();
        listofWhereClause=getListofWhereClause(listOfFieldOperatorValueWrapper);
        for(String stringobject : listofWhereClause){
            if(stringobject != '\'\''){
                query += ' AND ' +stringobject;
            }
        }
        query+=' LIMIT '+String.escapeSingleQuotes(configuration.recordLimit ) ;
        userStoryList = Database.query(query);
        return userStoryList;
    }
    @TestVisible
    private static  List<FieldSetMember> getFieldSetFields(String selectFieldSet) {
        String fromObject= FilterConstant.USER_STORY;
        return fflib_SObjectDescribe.getDescribe(fromObject).getFieldSets().get(selectFieldSet).getFields();
    }
    @TestVisible
    private static String getSelectFields(String selectFieldSet) {
        Set<String> fields = new Set<String>();
        for (FieldSetMember field : getFieldSetFields(selectFieldSet)) {
            String fieldToAdd = field.getFieldPath();
            if (field.getType() == DisplayType.REFERENCE) {
                if (field.getFieldPath().endsWith(DatatableConstants.CUSTOM_FIELD_PATH_END)) {
                    fieldToAdd = field.getFieldPath().replace(DatatableConstants.CUSTOM_FIELD_PATH_END, DatatableConstants.CUSTOM_REFERENCE_FIELD_NAME);
                } else if (field.getFieldPath().endsWith(DatatableConstants.ID)) {
                    // Trick to no to replace other possible appearances of 'Id' in the field name
                    fieldToAdd = field.getFieldPath() + DatatableConstants.DOUBLE_UNDERSCORE;
                    fieldToAdd = fieldToAdd.replace(DatatableConstants.ID + DatatableConstants.DOUBLE_UNDERSCORE, DatatableConstants.STANDARD_REFERENCE_FIELD_NAME);
                }
            }
            fields.add(fieldToAdd);
        }
        return String.join(new List<String>(fields), DatatableConstants.COMMA);
        
    }
    @TestVisible
    private static List<String> getListofWhereClause(List<FieldOperatorValueWrapper> listOfFieldOperatorValueWrapper ){
        List<String> listofWhereClause = new List<String>();

        for(FieldOperatorValueWrapper objOfWrapper :listOfFieldOperatorValueWrapper){
            listofWhereClause.add(getWhereClause(objOfWrapper));
        }
        return listofWhereClause;

    }
    @TestVisible
    private static string getWhereClause(FieldOperatorValueWrapper objOfWrapper ){
        if(objOfWrapper.fieldTypeSelected==FilterConstant.FIELDTYPE_BOOLEAN || objOfWrapper.fieldTypeSelected==FilterConstant.FIELDTYPE_DOUBLE){
            return getNonStringClause(objOfWrapper);
        }else{
            return getStringClause(objOfWrapper) ; 
        }
    }
    @TestVisible
    private static string getStringClause(FieldOperatorValueWrapper objOfWrapper ){
        objOfWrapper.valueForField = String.escapeSingleQuotes(objOfWrapper.valueForField);
        objOfWrapper.fieldSelected = String.escapeSingleQuotes(objOfWrapper.fieldSelected);
        objOfWrapper.operatorUsed = String.escapeSingleQuotes(objOfWrapper.operatorUsed);

        String clause = objOfWrapper.fieldSelected+objOfWrapper.operatorUsed+'\''+objOfWrapper.valueForField+'\'';
        if(objOfWrapper.operatorUsed == FilterConstant.OPERATOR_LIKE){
            clause = objOfWrapper.fieldSelected+' '+objOfWrapper.operatorUsed+'\''+'%'+objOfWrapper.valueForField +'%' +'\'';    
        }
        else if(objOfWrapper.operatorUsed ==FilterConstant.OPERATOR_NOT_LIKE){
            clause = 'Not (' + objOfWrapper.fieldSelected+' Like'+'\''+'%'+objOfWrapper.valueForField +'%' +'\'' + ')';
        }
        else if(objOfWrapper.operatorUsed == FilterConstant.OPERATOR_STARTS_WITH){
            clause = objOfWrapper.fieldSelected+' Like'+ '\''+objOfWrapper.valueForField +'%' +'\'' ;
        }
        return clause;
    }
    @TestVisible
    private static string getNonStringClause(FieldOperatorValueWrapper objOfWrapper ){
        objOfWrapper.valueForField = String.escapeSingleQuotes(objOfWrapper.valueForField);
        objOfWrapper.fieldSelected = String.escapeSingleQuotes(objOfWrapper.fieldSelected);
        objOfWrapper.operatorUsed = String.escapeSingleQuotes(objOfWrapper.operatorUsed);
        if(objOfWrapper.fieldTypeSelected==FilterConstant.FIELDTYPE_DOUBLE && !objOfWrapper.valueForField.isNumericspace()){
            objOfWrapper.valueForField=FilterConstant.INVALID_STRING;                 
         }
         else if(objOfWrapper.fieldTypeSelected==FilterConstant.FIELDTYPE_DOUBLE && String.isBlank(objOfWrapper.ValueForField)){
            objOfWrapper.valueForField=null;                 
         }   
         return (objOfWrapper.fieldSelected+objOfWrapper.operatorUsed+objOfWrapper.valueForField);
        
    }

    public class FieldListWrapper{
        @AuraEnabled public String fieldName;
        @AuraEnabled public String fieldApi;
        @AuraEnabled public String type;
        @AuraEnabled public List<String> options = new List<String>(); 
        public FieldListWrapper(Schema.describefieldresult dField){
            fieldName=dfield.getLabel();
            fieldApi=dfield.getname();
            type=String.Valueof(dfield.getType());
        } 
        public void createFieldList(Schema.describefieldresult dfield,Map <String, Schema.SObjectField> mapOfDesiredObject){
            if(String.Valueof(dfield.getType()) ==FilterConstant.FIELDTYPE_PICKLIST){
                String fieldName = dfield.getname();
                Schema.DescribeFieldResult fieldResult = mapOfDesiredObject.get(fieldName).getDescribe();
                List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
                for( Schema.PicklistEntry pickListVal : ple){
                    options.add(pickListVal.getLabel());
                }
            }else if(String.Valueof(dfield.getType()) == DatatableConstants.FIELDTYPE_REFERENCE){
                String fieldApiToAdd='';
                String fieldLabelToAdd='';
                if (dfield.getname().endsWith(DatatableConstants.CUSTOM_FIELD_PATH_END)) {
                    fieldApiToAdd = dfield.getname().replace(DatatableConstants.CUSTOM_FIELD_PATH_END, DatatableConstants.CUSTOM_REFERENCE_FIELD_NAME);
                    fieldLabelToAdd=dfield.getLabel()+' ' + DatatableConstants.NAME;
                } else if (dfield.getname().endsWith(DatatableConstants.ID)) {
                    // Trick to no to replace other possible appearances of 'Id' in the field name
                    fieldApiToAdd = dfield.getname() + DatatableConstants.DOUBLE_UNDERSCORE;
                    fieldApiToAdd = fieldApiToAdd.replace(DatatableConstants.ID + DatatableConstants.DOUBLE_UNDERSCORE, DatatableConstants.STANDARD_REFERENCE_FIELD_NAME);
                    fieldLabelToAdd=dfield.getLabel()+' ' + DatatableConstants.NAME;
                } 
                fieldApi=fieldApiToAdd;
                fieldName=fieldLabelToAdd;
            }        
        }

        
    }
    public class FieldOperatorValueWrapper{
        @AuraEnabled public String fieldSelected;
        @AuraEnabled public String operatorUsed;
        @AuraEnabled public String valueForField;
        @AuraEnabled public String fieldLableSelected;
        @AuraEnabled public String operatorLableSelected;
        @AuraEnabled public Boolean isEmpty;
        @AuraEnabled public String fieldTypeSelected;
        @AuraEnabled public String id;
    }
    public class FilterConfiguration{
        @AuraEnabled
        public String filterString { get; set; }
        @AuraEnabled
        public String ownerString { get; set; }
        @AuraEnabled
        public String recordId { get; set; }
        @AuraEnabled
        public String selectFieldSet { get; set; }
        @AuraEnabled
        public String recordLimit { get; set; }

    }
}