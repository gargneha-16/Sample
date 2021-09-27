@IsTest
private class FunctionResultMonitorTest {
    @TestSetup
    private static void setup() {
        insertData();
    }

    @IsTest
    private static void getDefaultTimeout() {
        // Exercise

        Test.startTest();
        Decimal timeout = new FunctionResultMonitor().timeout();
        Test.stopTest();

        // Verify

        String defaultTimeout = [SELECT Text_Field__c FROM Copado_Setting__mdt WHERE DeveloperName = 'Functions_backend_communication_timeout']
        ?.Text_Field__c;
        if (String.isNotBlank(defaultTimeout)) {
            System.assertEquals('330', String.valueOf(timeout), '');
        } else {
            System.assertEquals(defaultTimeout, String.valueOf(timeout), '');
        }
    }

    @IsTest
    private static void execute() {
        // Exercise

        Test.startTest();
        Database.executeBatch(new FunctionResultMonitor(), 1000);
        Test.stopTest();

        // Verify

        Result__c result = [SELECT Error_Message__c, Status__c FROM Result__c LIMIT 1];
        String progressStatus = String.format(Label.Function_Execution_Timed_Out, new List<String>{ '-1' });
        System.assertEquals('Failed', result.Status__c, 'Status for expired functions should be updated to failed.');
        System.assertEquals(progressStatus, result.Error_Message__c, 'Progress Status should be updated in the callback class');
    }

    // HELPER

    private static void insertData() {
        Function__c function = new Function__c(
            Name = 'muleDeploy',
            API_Name__c = 'muleDeploy',
            Script__c = 'echo hello world $par1',
            Type__c = 'Custom',
            //Timeout__c = -1, // Set timeout to a negative value to trigger function expiration
            Parameters__c = '[{"name": "LogLevel", "defaultValue": "ERROR", "required": false}]',
            Worker_Size__c = 'S'
        );
        insert function;

        insert new Result__c(
            Job_Type__c = function.API_Name__c,
            Start_Time__c = Datetime.now().addMinutes(-10),
            Status__c = 'In Progress',
            Function__c = function.Id,
            //Timeout__c = function.Timeout__c,
            Function_Worker_Size__c = function.Worker_Size__c
        );
    }
}