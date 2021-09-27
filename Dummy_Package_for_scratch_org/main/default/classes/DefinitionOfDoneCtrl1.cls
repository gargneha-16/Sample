public with sharing class DefinitionOfDoneCtrl1 {
    //PUBLIC
    @AuraEnabled(cacheable=true)
    public static List<Test> getTests(Id recordId) {
        List<Test> result = new List<Test>();
        List<Test__c> tests = new TestsSelector().byUserStoryId(new Set<Id>{ recordId });
        Map<Id, String> testStatusById = getTestStatusById(new Map<Id, Test__c>(tests).keyset());
        for (Test__c test : tests) {
            result.add(new Test(test, testStatusById.get(test.Id)));
        }
        
        return result;
    }

    //PRIVATE
    private static Map<Id, String> getTestStatusById(Set<Id> testIds) {
        Map<Id, String> result = new Map<Id, String>();
        List<AggregateResult> testResult = [
            SELECT Test__c, Max(LastModifiedDate), Progress_Status__c
            FROM Result__c 
            WHERE Test__c IN :testIds WITH SECURITY_ENFORCED
            GROUP BY Test__c, Progress_Status__c 
        ];
        for (AggregateResult agr : testResult) {
            Id testId = (Id) agr.get('Test__c');
            String status = (String) agr.get('Progress_Status__c');
            if (!result.containsKey(testId)) {
                result.put(testId, status);
            }
        }

        return result;
    }
    public with sharing class Test {
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
        public Test(Test__c test, String status) {
            this.id = test.id;
            this.name = test.Name;
            this.type = test.Category__c;
            this.level =  String.isNotBlank(test.User_Story__c) ? 'User Story' : '';
            this.isSuccess = String.isNotBlank(status) && status.equalsIgnoreCase('success') ? true : false;
            this.url = '/' + id;
        }
    }
}