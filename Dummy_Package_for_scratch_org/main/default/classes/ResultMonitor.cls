public with sharing class ResultMonitor {
    // PUBLIC

    @AuraEnabled(cacheable=false)
    public static Result__c result(Id id) {
        try {
            List<Result__c> results = Database.query(query(id));

            if (results.isEmpty()) {
                throw new ResultMonitorException(Label.Result_not_Found);
            }

            return results[0];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // PRIVATE

    private static String query(Id id) {
        return 'SELECT Name, Status__c, Progress_Status__c FROM Result__c WHERE Id = :id WITH SECURITY_ENFORCED';
    }

    private class ResultMonitorException extends Exception {
    }
}