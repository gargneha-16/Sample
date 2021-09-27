public with sharing class DefinitionOfDoneCtrl {
    //PUBLIC
    @AuraEnabled(cacheable=true)
    public static List<TestWrapper> getTests(Id recordId) {
        try{
            List<TestWrapper> result = new List<TestWrapper>();

            for (Test__c test : new TestsSelector().byParentWithLatestResult(recordId)) {
                parseToTestWrapper(test,result);
            }

            return result;
        }catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }
    
    @AuraEnabled
    public static void deleteTest(Id recordId) {
        try {
            List<Test__c> tests = new TestsSelector().byIds(new Set<Id>{ recordId });
            Utilities.Secure_DML(tests, Utilities.DML_Action.DEL, Schema.SObjectType.Test__c);
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    //PRIVATE
    private static void parseToTestWrapper(Test__c test, List<TestWrapper> testWrapper) {
        if (test.Results__r.isEmpty()) {
            testWrapper.add(new TestWrapper(test, ''));
        } else {
            testWrapper.add(new TestWrapper(test, test.Results__r[0].Status__c));
        }
    }

    public with sharing class TestWrapper {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String level;
        @AuraEnabled
        public String url;
        @AuraEnabled
        public Boolean isSuccess;
        public TestWrapper(Test__c test, String status) {
            this.id = test.id;
            this.name = test.Name;
            this.type = test.Category__c;
            this.level =  String.isNotBlank(test.User_Story__c) ? 'User Story' : '';
            this.isSuccess = String.isNotBlank(status) && status.equalsIgnoreCase('success') ? true : false;
            this.url = '/' + id;
        }
    }
}