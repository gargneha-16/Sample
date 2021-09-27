public with sharing class FunctionResultMonitor implements Database.Batchable<sObject>, Schedulable {
    private final Datetime now;
    private final Decimal timeout;

    // CTOR

    public FunctionResultMonitor() {
        now = Datetime.now();
        timeout = Test.isRunningTest() ? -1 : timeout();
    }

    // PUBLIC

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query());
    }

    public void execute(Database.BatchableContext BC, List<Result__c> results) {
        List<MC_Result__e> events = new List<MC_Result__e>();
        for (Result__c result : results) {
            if (timedOut(result)) {
                events.add(event(result));
            }
        }
        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }

    public void finish(Database.BatchableContext BC) {
    }

    public void execute(SchedulableContext SC) {
        Database.executeBatch(new FunctionResultMonitor(), 1000);
    }

    public static void start() {
        // Schedule to run every 5 minutes
        for (Integer i = 0; i < 60; i += 5) {
            String minute = (i < 10 ? '0' : '') + i;
            String cronExpression = '0 ' + minute + ' * * * ?';
            System.schedule('FunctionResultMonitor ' + minute, cronExpression, new FunctionResultMonitor());
        }
    }

    // PRIVATE

    private String query() {
        return 'SELECT LastModifiedDate, Status__c, Progress_Status__c FROM Result__c WHERE Function__c != null AND Status__c = \'In Progress\' WITH SECURITY_ENFORCED';
    }

    @TestVisible
    private Decimal timeout() {
        Decimal result = 330; // default timeout in seconds

        try {
            String defaultTimeout = defaultTimeout();
            if (String.isNotBlank(defaultTimeout)) {
                result = Decimal.valueOf(defaultTimeout);
            }
        } catch (Exception ex) {
            // no action required. If query fails, return default timeout.
        }

        return result;
    }

    private String defaultTimeout() {
        return [SELECT Text_Field__c FROM Copado_Setting__mdt WHERE DeveloperName = 'Functions_backend_communication_timeout' WITH SECURITY_ENFORCED]
        ?.Text_Field__c;
    }

    private Boolean timedOut(Result__c result) {
        return secondsElapsed(result.LastModifiedDate) > timeout;
    }

    private Long secondsElapsed(Datetime lastModifiedDate) {
        Long milliseconds = now.getTime() - lastModifiedDate.getTime();
        Long seconds = milliseconds / 1000;
        return seconds;
    }

    private MC_Result__e event(Result__c result) {
        return new MC_Result__e(
            ResultId__c = result.Id,
            isFinished__c = true,
            isSuccess__c = false,
            Error_Message__c = String.format(Label.Function_Execution_Timed_Out, new List<String>{ String.valueOf(timeout) })
        );
    }
}