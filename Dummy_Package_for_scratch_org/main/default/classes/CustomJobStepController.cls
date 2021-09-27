public with sharing class CustomJobStepController {
    @AuraEnabled(cacheable=true)
    public static String getNamespace() {
        try {
            return Settings.ns;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled(cacheable=false)
    public static JobStep__c getStep(String stepId) {
        try {
            return [SELECT Name, Type__c, CustomType__c, Order__c, ConfigJson__c FROM JobStep__c WHERE Id = :stepId WITH SECURITY_ENFORCED];
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled(cacheable=false)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Id saveStep(JobStep__c record) {
        try {
            if (String.isBlank(record.Id)) {
                record.Order__c = getOrder(parentId(record));
            }

            JobStep__c step = (JobStep__c) Security.stripInaccessible(AccessType.UPSERTABLE, new List<JobStep__c>{ record }).getRecords()[0];
            upsert step;

            return step.Id;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<StepOption> getStepOptions() {
        List<StepOption> result = new List<StepOption>();

        try {
            for (MC_Custom_Job_Step__mdt record : [
                SELECT LWC_Name__c, Platform__c, CustomType__c, NamespacePrefix
                FROM MC_Custom_Job_Step__mdt
                ORDER BY CustomType__c NULLS FIRST
            ]) {
                result.add(new StepOption(record.CustomType__c, record.Platform__c, lwcName(record)));
            }
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }

        return result;
    }

    // PRIVATE

    private static String lwcName(MC_Custom_Job_Step__mdt config) {
        return (String.isBlank(config.NamespacePrefix) ? 'c' : config.NamespacePrefix) + ':' + config.LWC_Name__c;
    }

    private static Id parentId(JobStep__c record) {
        return String.isNotBlank(record.JobTemplate__c) ? record.JobTemplate__c : record.JobExecution__c;
    }

    private static Integer getOrder(String parentId) {
        Integer result = 1;

        try {
            List<JobStep__c> steps = [
                SELECT Order__c
                FROM JobStep__c
                WHERE (JobTemplate__c = :parentId OR JobExecution__c = :parentId) AND Order__c != NULL
                WITH SECURITY_ENFORCED
                ORDER BY Order__c DESC
                LIMIT 1
            ];
            if (!steps.isEmpty()) {
                result = (Integer) steps[0].Order__c + 1;
            }
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }

        return result;
    }

    public class StepOption {
        @AuraEnabled
        public String type;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String component;

        public StepOption(String type, String platform, String component) {
            this.type = type;
            this.label = label(platform);
            this.component = component;
        }

        private String label(String platform) {
            return type + (String.isNotBlank(platform) ? ' - ' + platform : '');
        }
    }
}