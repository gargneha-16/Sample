@IsTest
public class JobTemplate extends DomainBuilder {

    public JobTemplate() {
        super(JobTemplate__c.SObjectType);
        set(JobTemplate__c.Version__c, 1);
    }

    public JobTemplate add(JobStep step) {
        return (JobTemplate) step.setParent(JobStep__c.JobTemplate__c, this);
    }
}