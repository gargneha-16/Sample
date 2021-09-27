@isTest
public class FilterComponentControllerTest {
    @isTest
    public static void testgetFields(){
        List<FilterComponentController.FieldListWrapper> listOfField=FilterComponentController.getFields();
        system.assert(listOfField.size()>0);
    }
    @isTest
    public static void testfilterUserStoryRecord(){
        User_Story__c  userStoryobj = new User_Story__c ();
        userStoryobj.User_Story_Title__c ='test user story';
        insert userStoryobj;
        String jsonString = '{"filterString":"[]","ownerString":"All User Stories","recordId":"a1T09000000RGKmEAO","selectFieldSet":"Sprint_Wall_Columns","recordLimit":10000}';

        List<User_Story__c> listOfUserStory = FilterComponentController.filterUserStoryRecord(jsonString);
		FilterComponentController.FieldOperatorValueWrapper obj= new FilterComponentController.FieldOperatorValueWrapper();
        obj.valueForField='2';
        obj.fieldLableSelected='Priority';
        obj.fieldSelected='Priority';
        obj.operatorLableSelected='Equal';
        obj.operatorUsed='=';
        obj.valueForField='test';
         
        FilterComponentController.getWhereClause(obj);
        FilterComponentController.getNonStringClause(obj);

        system.assert(listOfUserStory.size()==0);
    }
}