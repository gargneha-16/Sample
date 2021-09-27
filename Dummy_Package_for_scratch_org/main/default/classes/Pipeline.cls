@IsTest
public class Pipeline extends DomainBuilder {

    public Pipeline(Repository rep) {
        super(Deployment_Flow__c.SObjectType);
        setParent(Deployment_Flow__c.Git_Repository__c, rep);

        set(Deployment_Flow__c.Active__c, true);
        set(Deployment_Flow__c.Main_Branch__c, 'main');
    }

    public Pipeline() {
        this( new Repository() );
    }

    public Pipeline add(Connection con) {
        return (Pipeline) con.setParent(Deployment_Flow_Step__c.Deployment_Flow__c, this);
    }

    public Pipeline add(Project prj) {
        return (Pipeline) prj.setParent(Project__c.Deployment_Flow__c, this);
    }
}