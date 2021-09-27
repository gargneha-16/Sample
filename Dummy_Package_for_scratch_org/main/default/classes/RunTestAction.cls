public with sharing class RunTestAction {
    public with sharing class Request {
        @InvocableVariable(label='Test ID')
        public Id testId;
    }
    public with sharing class Result {
        @InvocableVariable(label='Result ID')
        public Id resultId;

        Result(Id resultId) {
            this.resultId = resultId;
        }
    }

    // PUBLIC

    @InvocableMethod(
        label='Run Individual Test'
        description='Run an individual test with the logic provided by the related extension package'
        category='Test'
    )
    public static List<Result> execute(List<Request> requests) {
        List<Test__c> tests = new TestsSelector().byIds(new Set<Id>{ requests[0].testId });
        List<Result__c> extensionResults = new RunTestsInExtension(tests).execute();

        return new List<Result>{ new Result(extensionResults[0].Id) };
    }
}