@IsTest
private class ResultMonitorTest {
    @TestSetup
    private static void setup() {
        insertData();
    }

    @IsTest
    private static void getRecord() {
        // Setup

        Result__c record = result();

        // Exercise

        Test.startTest();
        Result__c result = ResultMonitor.result(record.Id);
        Test.stopTest();

        // Verify

        System.assertEquals(record.Id, result.Id, 'Incorrect result retrieved.');
        System.assertEquals(record.Status__c, result.Status__c, 'Incorrect result status retrieved.');
        System.assertEquals(record.Progress_Status__c, result.Progress_Status__c, 'Incorrect result progress status retrieved.');
    }

    @IsTest
    private static void error() {
        // Exercise

        Exception ex;
        Test.startTest();
        try {
            Result__c result = ResultMonitor.result(null);
        } catch (Exception error) {
            ex = error;
        }
        Test.stopTest();

        // Verify

        System.assert(ex != null, 'No error was thrown for a null result id.');
    }

    // Helpers

    private static Result__c result() {
        return [SELECT Status__c, Progress_Status__c FROM Result__c LIMIT 1];
    }

    private static void insertData() {
        insert new Result__c(Status__c = 'In Progress', Progress_Status__c = 'Executing', Job_Type__c = 'echo');
    }
}