@IsTest
public class Step extends DomainBuilder {

    public Step(Deployment dep) {
        super(Step__c.SObjectType);
        setParent(Step__c.Deployment__c, dep);
    }

    public Step() {
        this ( new Deployment() );
    }
}