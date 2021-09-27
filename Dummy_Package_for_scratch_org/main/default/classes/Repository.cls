@IsTest
public class Repository extends DomainBuilder {

    public Repository() {
        super(Git_Repository__c.SObjectType);

        name(new Random().string());
    }

    public Repository name(String value) {
        return (Repository) set(Git_Repository__c.Name, value);
    }
}