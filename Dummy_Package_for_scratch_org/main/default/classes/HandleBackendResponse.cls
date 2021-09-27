@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class HandleBackendResponse {
    @TestVisible
    private static String mockCallback;

    private final Map<String, Decimal> workerSizeCredits = new Map<String, Integer>{ 'S' => 1, 'M' => 2, 'L' => 4, 'XL' => 8 };
    private List<MC_Result__e> records;

    private Integer totalUsedCredits = 0;

    // CONSTRUCTOR

    public HandleBackendResponse(List<MC_Result__e> records) {
        this.records = records;
    }

    @SuppressWarnings('PMD.EmptyStatementBlock')
    public HandleBackendResponse() {
    }

    // PUBLIC

    public void execute() {
        List<Result__c> resultsToUpdate = resultsToUpdate();

        update Security.stripInaccessible(AccessType.UPDATABLE, resultsToUpdate).getRecords();
        updateCreditUsage();
        executeCallbacks(resultsToUpdate);
    }

    public void resultCallback(Function__c function, Id resultId, String status) {
        Result__c result = new ResultsSelector().byIds(new Set<Id>{ resultId })[0];
        result.Status__c = status;

        resultCallback(function, result);
    }

    // PRIVATE

    private List<Result__c> resultsToUpdate() {
        List<Result__c> result = new List<Result__c>();

        Map<Id, MC_Result__e> events = eventsByResult(records);

        for (Result__c record : new ResultsSelector().inProgressByIds(events.keySet())) {
            MC_Result__e event = events.get(record.Id);
            Result__c updatedResult = updatedResult(record, event);

            if (event?.IsFinished__c == true) {
                totalUsedCredits += (Integer) updatedResult.Custom_Function_Used_Credits__c;
            }

            result.add(updatedResult);
        }

        return result;
    }

    private Result__c updatedResult(Result__c record, MC_Result__e event) {
        Integer usedMinutes = (isCustom(record) ? usedMinutes(record.Start_Time__c) : null);

        record.Status__c = statusFromEvent(event);
        record.Result_Data__c = setValue(record.Result_Data__c, event?.Result_Data__c);
        record.Error_Message__c = setValue(record.Error_Message__c, event?.Error_Message__c);
        record.Progress_Status__c = setValue(record.Progress_Status__c, event?.Progress_Status__c);
        record.End_Time__c = (event?.IsFinished__c == true ? Datetime.now() : null);
        record.Custom_Function_Used_Minutes__c = usedMinutes;
        record.Custom_Function_Used_Credits__c = usedCredits(usedMinutes, record.Function_Worker_Size__c);

        return record;
    }

    private String setValue(String oldValue, String newValue) {
        return String.isNotBlank(newValue) ? newValue : oldValue;
    }

    private Boolean isCustom(Result__c result) {
        return result.Function__r.Type__c != 'Standard';
    }

    private void updateCreditUsage() {
        List<CustomFunctionUsage__c> usage = monthlyUsage();

        if (usage.isEmpty()) {
            setCustomFunctionUsage(totalUsedCredits, null);
        } else {
            Integer credits = Integer.valueOf(usage[0].Credits__c + totalUsedCredits);
            setCustomFunctionUsage(credits, usage[0].Id);
        }

        updateMonthlyCreditUsage(totalUsedCredits, usage.isEmpty());
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private void setCustomFunctionUsage(Integer totalUsedCredits, Id usageId) {
        // Note: protected custom setting
        if (String.isBlank(usageId)) {
            insert new CustomFunctionUsage__c(Name = String.valueOf(Date.today()), Year_Month__c = Date.today(), Credits__c = totalUsedCredits);
        } else {
            update new CustomFunctionUsage__c(Id = usageId, Credits__c = totalUsedCredits);
        }
    }

    @future
    private static void updateMonthlyCreditUsage(Integer totalUsedCredits, Boolean resetCredits) {
        Integer monthlyTotal = resetCredits ? 0 : FeatureManagement.checkPackageIntegerValue('CustomFunctionCreditUsage');
        FeatureManagement.setPackageIntegerValue('CustomFunctionCreditUsage', monthlyTotal + totalUsedCredits);
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private List<CustomFunctionUsage__c> monthlyUsage() {
        // Note: Protected system object, no security checks needed.
        return [
            SELECT Credits__c
            FROM CustomFunctionUsage__c
            WHERE CALENDAR_YEAR(Year_Month__c) = :Date.today().year() AND CALENDAR_MONTH(Year_Month__c) = :Date.today().month()
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    private Integer usedMinutes(Datetime startDate) {
        Long startTime = startDate.getTime();
        Long endTime = DateTime.now().getTime();
        Long seconds = (endTime - startTime) / 1000;

        return Math.ceil(seconds / 60).intValue() == 0 ? 1 : Math.ceil(seconds / 60).intValue();
    }

    private Integer usedCredits(Long minutes, String workerSize) {
        return String.isBlank(workerSize) || minutes == null ? 0 : Integer.valueOf(minutes * workerSizeCredits.get(workerSize));
    }

    private Map<Id, MC_Result__e> eventsByResult(List<MC_Result__e> events) {
        Map<Id, MC_Result__e> result = new Map<Id, MC_Result__e>();

        for (MC_Result__e event : events) {
            result.put(event.ResultId__c, event);
        }

        return result;
    }

    private Map<Id, Function__c> functions(List<Result__c> results) {
        Set<Id> functionIds = new Set<Id>();

        for (Result__c result : results) {
            functionIds.add(result.Function__c);
        }

        return new Map<Id, Function__c>(new FunctionsSelector().byIds(functionIds));
    }

    private String statusFromEvent(MC_Result__e event) {
        String result;

        if (event?.IsFinished__c == true) {
            if (event.isSuccess__c) {
                result = 'Success';
            } else {
                result = 'Failed';
            }
        } else {
            result = 'In Progress';
        }

        return result;
    }

    private void executeCallbacks(List<Result__c> results) {
        Map<Id, Function__c> functions = functions(results);

        for (Result__c result : results) {
            try {
                functionCallback(functions.get(result.Function__c), result);
            } catch (Exception ex) {
                result = error(result, ex);
            }

            resultCallback(functions.get(result.Function__c), result);
        }
    }

    private void functionCallback(Function__c function, Result__c result) {
        switch on function.Callback_Type__c {
            when 'ApexClass' {
                executeApex(function, result);
            }
            when 'Flow' {
                executeFlow(function, result);
            }
        }
    }

    private void executeApex(Function__c function, Result__c result) {
        apexCallback(callbackName(function.ApexClass__c)).execute(function, result, result.Status__c);
    }

    private void executeFlow(Function__c function, Result__c result) {
        try {
            createFlowInterview(callbackName(function.FlowHandler__c), flowParameters(function, result));
        } catch (Exception ex) {
            throw new ApplicationException(String.format(Label.Flow_Callback_Failed, new List<String>{ ex.getMessage() }));
        }
    }

    private void resultCallback(Function__c function, Result__c result) {
        if (String.isNotBlank(result.ApexCallback__c)) {
            apexCallback(result.ApexCallback__c).execute(function, result, result.Status__c);
        }
    }

    private String callbackName(String callback) {
        String result;

        if (Test.isRunningTest() && String.isNotBlank(mockCallback)) {
            result = mockCallback;
        } else if (String.isNotBlank(callback)) {
            result = callback;
        }

        return result;
    }

    private Map<String, Object> flowParameters(Function__c function, Result__c result) {
        return new Map<String, Object>{ 'function' => function, 'result' => result, 'status' => result.Status__c };
    }

    private void createFlowInterview(String flowName, Map<String, Object> parameters) {
        Flow.Interview.createInterview(namespace(flowName), handler(flowName), parameters).start();
    }

    private MCCallBack apexCallback(String apexClass) {
        try {
            return ((MCCallBack) Type.forName(namespace(apexClass), handler(apexClass)).newInstance());
        } catch (Exception ex) {
            throw new ApplicationException(
                String.format(Label.Callback_not_Found, new List<String>{ 'ApexClass', apexClass }) +
                ' ' +
                Label.Callback_not_Found_Information
            );
        }
    }

    private String namespace(String name) {
        return name.contains('.') ? name.substringBefore('.') : '';
    }

    private String handler(String name) {
        return name.contains('.') ? name.substringAfter('.') : name;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private Result__c error(Result__c result, Exception ex) {
        // Note: needed for ease of internal troubleshooting when an error occurs in a subscriber org.
        System.debug(LoggingLevel.ERROR, 'Error in function/result callback: ' + ex.getMessage() + ': ' + ex.getStackTraceString());

        result.Status__c = 'Failed';
        result.End_Time__c = Datetime.now();
        result.Progress_Status__c = Label.Error;
        result.Error_Message__c = String.format(Label.Function_Callback_Failed, new List<String>{ ex.getMessage() });

        update Security.stripInaccessible(AccessType.UPDATABLE, new List<Result__c>{ result }).getRecords();

        return result;
    }
}