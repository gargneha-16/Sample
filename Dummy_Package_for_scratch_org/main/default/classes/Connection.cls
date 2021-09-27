@IsTest
public class Connection extends DomainBuilder {

    public Connection(Pipeline pip, Environment source, Environment destination) {
        super(Deployment_Flow_Step__c.SObjectType);
        setParent(Deployment_Flow_Step__c.Deployment_Flow__c, pip);
        setParent(Deployment_Flow_Step__c.Source_Environment__c, source);
        setParent(Deployment_Flow_Step__c.Destination_Environment__c, destination);
    }

    public Connection() {
        this( new Pipeline(), new Environment(), new Environment() );
    }

    public Connection(Pipeline pip) {
        this( pip, new Environment(), new Environment() );
    }

    public Connection(Environment source, Environment destination) {
        this( new Pipeline(), source, destination );
    }
}