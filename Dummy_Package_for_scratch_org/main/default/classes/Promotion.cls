@IsTest
public class Promotion extends DomainBuilder {

    public Promotion(Project prj, Release rls, Credential source, Environment sourceEnv, Credential dest, Environment destEnv) {
        super(Promotion__c.SObjectType);
        setParent(Promotion__c.Project__c, prj);
        setParent(Promotion__c.Release__c, rls);
        setParent(Promotion__c.Source_Org_Credential__c, source);
        setParent(Promotion__c.Source_Environment__c, sourceEnv);
        setParent(Promotion__c.Destination_Org_Credential__c, dest);
        setParent(Promotion__c.Destination_Environment__c, destEnv);

        Pipeline pip = (Pipeline) prj.parentByRelationship.get(Project__c.Deployment_Flow__c);

        new Connection(pip, sourceEnv, destEnv);
    }

    public Promotion(Release rls, Credential source, Credential dest) {
        this( (Project) rls.parentByRelationship.get(Release__c.Project__c), rls, source, (Environment) source.parentByRelationship.get(Org__c.Environment__c), dest, (Environment) dest.parentByRelationship.get(Org__c.Environment__c) );
    }

    public Promotion() {
        super(Promotion__c.SObjectType);
    }
}