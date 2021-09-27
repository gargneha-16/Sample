@IsTest
public class Credential extends DomainBuilder {

    public Credential(Environment env) {
        super(Org__c.SObjectType);
        set(Org__c.Validated_Date__c, System.now());
        setParent(Org__c.Environment__c, env);
    }

    public Credential() {
        this( new Environment() );
    }
}