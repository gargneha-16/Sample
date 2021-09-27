public with sharing class SetJobTemplateApiName {

    private List<JobTemplate__c> records;

    // CONSTRUCTOR

    public SetJobTemplateApiName(List<JobTemplate__c> records) {
        this.records = records;
    }

    // PUBLIC

    public void execute() {
        for(JobTemplate__c record : records) {
            record.ApiName__c = record.Name + '_' + record.Version__c;
        }
    }
}