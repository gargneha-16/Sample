public with sharing class WorkSetService implements CLIInterface {

    // PUBLIC

    public String run(CliProxy.CLIWrapper record) {
        Savepoint savePoint = Database.setSavepoint();

        try {
            assertAccess();

            Request request = (Request) JSON.deserialize(record.body, Request.class);
            User_Story__c userStory = selectUserStoryBy(request.criteria, request.value);

            if(String.isNotBlank(request.credentialName)) {
                updateCredential(userStory, request.credentialName);
                userStory = selectUserStoryBy(request.criteria, request.value);
            }

            List<Deployment_Flow_Step__c> pipelineConnList = [SELECT Id, Branch__c
                                                                FROM Deployment_Flow_Step__c
                                                                WHERE Deployment_Flow__c = :userStory.Project__r.Deployment_Flow__c
                                                                AND Source_Environment__c = :userStory.Environment__c
                                                                WITH SECURITY_ENFORCED];

            if (pipelineConnList.isEmpty()) {
                throw new CliException(Label.Org_Credential_Not_Included_In_Deployment_Flow);
            }

            return toResponse(userStory, pipelineConnList[0].Branch__c);
        }
        catch(Exception ex) {
            Database.rollback(savepoint);
            throw new CliException(ex.getMessage());
        }
    }

    // PRIVATE

    private String toResponse(User_Story__c userStory, String branch) {
        Response result = new Response(CliSfDataWrapper.StatusResult.OK.name(), branch, userStory);

        return (JSON.serialize(result));
    }


    private void updateCredential(User_Story__c userStory, String credentialName) {
        List<Org__c> orgs = [SELECT Id, Name FROM Org__c WHERE Name = :credentialName WITH SECURITY_ENFORCED];

        if(orgs.isEmpty()) {
            throw new CliException(Label.InvalidOrgCredential);
        }
        userStory.Org_Credential__c = orgs[0].Id;
        userStory.Environment__c = null;

        update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject> { userStory }).getRecords();
    }


    private User_Story__c selectUserStoryBy(String field, String value) {
        String soqlString = 'SELECT Id, Name, Org_Credential__c, Environment__c, Base_Branch__c, Project__r.Deployment_Flow__c, Project__r.Deployment_Flow__r.Main_Branch__c, Release__r.Base_Branch__c, (SELECT External_Id__c FROM User_Story_Commits__r ORDER BY Snapshot_Commit__r.Commit_Date__c DESC LIMIT 1) FROM User_Story__c WHERE {0} = :value LIMIT 1';
        String dynamicQuery = String.format(soqlString, new List<String>{ String.escapeSingleQuotes(field) });

        List<User_Story__c> result = Database.query(dynamicQuery);

        if(result.isEmpty()) {
            throw new CliException(String.format(Label.NoUserStoryFound, new List<String> { field, value}));
        }

        return result[0];
    }


    private void assertAccess() {
        List<String> checkOlsList = CliSecurityService.checkOLS(
            new List<String>{ Schema.SObjectType.User_Story__c.getName(), Schema.SObjectType.Deployment_Flow_Step__c.getName() }
        );

        if (!checkOlsList.isEmpty()) {
            throw new CliException(Label.Insufficient_Access + checkOlsList);
        }
    }


    @TestVisible
    private class Request {
        public String value;
        public String criteria;
        public String credentialName;
    }


    @TestVisible
    private class Response extends CliSfDataWrapper {
        public User_Story__c userStory;
        public String environmentBranch;

        public Response(String status, String environmentBranch, User_Story__c userStory) {
            this.status = status;
            this.userStory = userStory;
            this.environmentBranch = environmentBranch;
        }
    }
}