@IsTest
public class Environment extends DomainBuilder {

    public Environment() {
        super(Environment__c.SObjectType);
    }

    public Environment(JobTemplate template) {
        this();
        setParent(Environment__c.CommitJobTemplateOverride__c, template);
    }

    public Environment add(Credential cred) {
        return (Environment) cred.setParent(Org__c.Environment__c, this);
    }

    public Environment add(Promotion pro) {
        return (Environment) pro.setParent(Promotion__c.Source_Environment__c, this);
    }
}