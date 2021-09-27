@IsTest
public class JobStep extends DomainBuilder {

    public JobStep() {
        super(JobStep__c.SObjectType);
        set(JobStep__c.Type__c, 'Flow');
        set(JobStep__c.ConfigJson__c, '{"flowName" : "MockedFlow"}');
    }
}