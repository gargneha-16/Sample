@IsTest
public class Release extends DomainBuilder {

    public Release(Project prj) {
        super(Release__c.SObjectType);
        setParent(Release__c.Project__c, prj);
    }

    public Release() {
        this( new Project() );
    }
}