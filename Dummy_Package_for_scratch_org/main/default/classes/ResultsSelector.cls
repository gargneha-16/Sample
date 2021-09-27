public inherited sharing class ResultsSelector extends fflib_SObjectSelector {
    public SObjectType getSObjectType() {
        return Result__c.sObjectType;
    }

    public List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{ 
            Result__c.Id, 
            Result__c.Name,
            Result__c.Function__c, 
            Result__c.Progress_Status__c, 
            Result__c.Error_Message__c, 
            Result__c.Result_Data__c, 
            Result__c.Status__c, 
            Result__c.ParentId__c, 
            Result__c.Job_Type__c, 
            Result__c.Job_Id__c, 
            Result__c.Start_Time__c, 
            Result__c.End_Time__c, 
            Result__c.ApexCallback__c, 
            Result__c.Function_Worker_Size__c,
            Result__c.Test__c,
            Result__c.Custom_Function_Used_Minutes__c, 
            Result__c.Custom_Function_Used_Credits__c
        };
    }

    public Result__c byId(Id recordId) {
        return byIds(new Set<Id> { recordId })[0];
    }

    public List<Result__c> byIds(Set<Id> ids) {
        return Database.query(selectFields().setCondition('Id IN :ids').toSOQL());
    }

    public List<Result__c> inProgressByIds(Set<Id> ids) {
        return Database.query(selectFields().setCondition('Id IN :ids AND Function__c != NULL AND Status__c = \'In Progress\'').toSOQL());
    }

    // PRIVATE

    private fflib_QueryFactory selectFields() {
        return newQueryFactory()
            .selectField('Function__r.Type__c')
            .selectField('JobStep__r.JobExecution__c');
    }
}