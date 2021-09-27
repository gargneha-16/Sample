public with sharing class MultiCloudAutomationsSelector extends fflib_SObjectSelector {

    @TestVisible
    private static Map<String, MultiCloudAutomation__mdt> mock = new Map<String, MultiCloudAutomation__mdt>();

    // PUBLIC

    public Schema.SObjectType getSObjectType() {
        return MultiCloudAutomation__mdt.SObjectType;
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            MultiCloudAutomation__mdt.Id,
            MultiCloudAutomation__mdt.PlatformName__c,
            MultiCloudAutomation__mdt.PromoteAPIName__c,
            MultiCloudAutomation__mdt.DeployAPIName__c,
            MultiCloudAutomation__mdt.PackageImportAPIName__c,
            MultiCloudAutomation__mdt.PackageVersionCreateApiName__c
        };
    }


    public MultiCloudAutomation__mdt byPlatform(String platformName) {
        return byPlatform(new Set<String> { platformName }).get(platformName);
    }


    public Map<String, MultiCloudAutomation__mdt> byPlatform(Set<String> platformNames) {
        Map<String, MultiCloudAutomation__mdt> result;

        if (Test.isRunningTest()) {
            result = mock;
        } else {
            List<MultiCloudAutomation__mdt> automations = Database.query(
                newQueryFactory().setCondition(MultiCloudAutomation__mdt.PlatformName__c + ' IN :platformNames').toSOQL()
            );
            result = groupByPlatform(automations);
        }

        return result;
    }

    public static void mock(Map<String, MultiCloudAutomation__mdt> automations) {
        mock = automations;
    }

    // PRIVATE

    private Map<String, MultiCloudAutomation__mdt> groupByPlatform(List<MultiCloudAutomation__mdt> automations) {
        Map<String, MultiCloudAutomation__mdt> result = new Map<String, MultiCloudAutomation__mdt>();

        for (MultiCloudAutomation__mdt automation : automations) {
            result.put(automation.PlatformName__c, automation);
        }

        return result;
    }
}