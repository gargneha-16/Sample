@SuppressWarnings('PMD')
public inherited sharing class RepositoryExpression extends DynamicExpression {
    private static final String HTTPS = 'https';
    private static final String SSH = 'ssh';

    private static final Pattern pattern1 = Pattern.compile('(?i)\\{\\$?(Context).(Repository).Credential\\}');

    private Git_Repository__c repository;

    // CONSTRUCTOR

    public RepositoryExpression(String contextId) {
        this.contextId = contextId;
    }

    // PUBLIC

    public override void prepare() {
        try {
            repository = repository();
        } catch (Exception ex) {
            throw new CopadoFunctionException(ex.getMessage());
        }
    }

    public override Boolean matches(Parameter parameter) {
        return matches(pattern1, parameter.value);
    }

    public override void parse(Parameter parameter) {
        if (matches(pattern1, parameter.value)) {
            parameter.value = (repository == null) ? null : JSON.serialize(credential(repository));
            parameter.sensitive(true);
        }
    }

    // PRIVATE

    private Git_Repository__c repository() {
        Git_Repository__c result = null;
        Id repositoryId = repositoryId();

        if (repositoryId != null) {
            result = [SELECT Id, URI__c FROM Git_Repository__c WHERE Id = :repositoryId WITH SECURITY_ENFORCED];
        }

        return result;
    }

    private Id repositoryId() {
        Id result = null;

        for (Parameter parameter : parameters) {
            if (matches(pattern1, parameter.value)) {
                result = toRepositoryId(contextId);
                break;
            }
        }

        return result;
    }

    private Id toRepositoryId(String repositoryId) {
        Id result = recordId();

        String sObjectName = result?.getSobjectType()?.getDescribe()?.getLocalName();

        if (!sObjectName.equalsIgnoreCase('Git_Repository__c')) {
            String query = 'SELECT Git_Repository__c FROM ' + String.escapeSingleQuotes(sObjectName) + ' WHERE Id = :result WITH SECURITY_ENFORCED';
            SObject parentRecord = Database.query(query);

            result = (Id) parentRecord.get('Git_Repository__c');
        }

        return result;
    }

    private Id recordId() {
        try {
            return Id.valueOf(contextId);
        } catch (Exception ex) {
            throw new CopadoFunctionException(String.format(Label.invalidContextId, new List<String>{ Label.Repository }));
        }
    }

    private Credential credential(Git_Repository__c repository) {
        Credential result = new Credential();

        result.url = repository.URI__c;
        result.type = repository.URI__c.startsWith(HTTPS) ? HTTPS : SSH;

        if (result.type == SSH) {
            setSSHKey(repository, result);
        } else if (result.type == HTTPS) {
            setUserNamePassword(repository, result);
        }

        return result;
    }

    private void setSSHKey(Git_Repository__c repository, Credential Credential) {
        for (Attachment attachment : [
            SELECT Name, Body
            FROM Attachment
            WHERE ParentId = :repository.Id AND Name IN ('id_rsa', 'id_rsa.pub')
            WITH SECURITY_ENFORCED
        ]) {
            if (attachment.Name == 'id_rsa') {
                Credential.privateKey = attachment.Body?.toString();
            } else {
                Credential.publicKey = attachment.Body?.toString();
            }
        }
    }

    private void setUserNamePassword(Git_Repository__c repository, Credential Credential) {
        Sensitive_Information__c gitRepositoryConfiguration = Sensitive_Information__c.getValues(repository.Id);
        Credential.username = gitRepositoryConfiguration?.Username__c;
        Credential.password = DeployAPI.decryptAPIKey(gitRepositoryConfiguration?.Password__c);

        List<Note> extraHeaders = [SELECT Body FROM Note WHERE ParentId = :repository.Id AND Title = 'Extra Headers' WITH SECURITY_ENFORCED];

        Credential.extraheaders = (extraHeaders.isEmpty()) ? '' : extraHeaders[0].Body;
    }

    // INNER

    public class Credential {
        public String type;
        public String url;
        public String branch;

        public String publicKey;
        public String privateKey;

        public String username;
        public String password;
        public String extraheaders;
    }
}