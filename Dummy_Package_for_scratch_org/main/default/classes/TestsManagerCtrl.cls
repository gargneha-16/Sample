public with sharing class TestsManagerCtrl {
    // PUBLIC

    @AuraEnabled
    public static void runTestsOf(Id parentId) {
        try {
            List<Test__c> tests = new TestsSelector().byParent(parentId);
            new RunTestsInExtension(tests).execute();
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled
    public static List<TestWrapper> getTests(Id parentId) {
        try {
            List<TestWrapper> result = new List<TestWrapper>();

            for (Test__c test : new TestsSelector().byParentWithLatestResult(parentId)) {
                parseToTestWrapper(test,result);
            }
         
            return result;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    // PRIVATE

    private static void parseToTestWrapper(Test__c test, List<TestWrapper> testWrapper) {
        if (test.Results__r.isEmpty()) {
            testWrapper.add(new TestWrapper(test, null));
        } else {
            testWrapper.add(new TestWrapper(test, test.Results__r[0]));
        }
    }

    public with sharing class TestWrapper {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String testType;
        @AuraEnabled
        public String testTool;
        @AuraEnabled
        public String runDate;
        @AuraEnabled
        public String result;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String testUrl;
        @AuraEnabled
        public String resultUrl;

        public TestWrapper(Test__c test, Result__c result) {
            this.id = test.id;
            this.name = test.Name;
            this.testType = test.Category__c;
            this.testTool =  test.Tool__c;
            this.testUrl = '/' + test.id;
            if(result != null){
                this.runDate = result.Start_Time__c!=null ? result.Start_Time__c.format('dd/MM/yyyy hh:mm a') : '';
                this.result = result.Name;
                this.status = result.Status__c;
                this.resultUrl = '/' + result.id;
            }
           
        }
    }
}