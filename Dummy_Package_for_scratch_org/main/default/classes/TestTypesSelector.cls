public with sharing class TestTypesSelector extends fflib_SObjectSelector {
    @TestVisible
    private static List<TestType__mdt> mock = new List<TestType__mdt>();

    // PUBLIC

    public Schema.SObjectType getSObjectType() {
        return TestType__mdt.SObjectType;
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            TestType__mdt.Id,
            TestType__mdt.ExecuteVia__c,
            TestType__mdt.Namespace__c,
            TestType__mdt.Category__c,
            TestType__mdt.Tool__c
        };
    }

    public List<TestType__mdt> getAll() {
        return Test.isRunningTest() ? mock : (List<TestType__mdt>) Database.query(newQueryFactory().setEnforceFLS(true).toSOQL());
    }

    public List<TestType__mdt> byTool(String tool) {
        return Test.isRunningTest()
            ? mock
            : (List<TestType__mdt>) Database.query(newQueryFactory().setEnforceFLS(true).setCondition('Tool__c = :tool').toSOQL());
    }

    public static void mock(List<TestType__mdt> providers) {
        mock = providers;
    }
}