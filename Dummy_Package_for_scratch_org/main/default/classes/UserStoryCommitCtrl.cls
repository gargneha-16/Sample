public with sharing class UserStoryCommitCtrl {

    // PUBLIC

    @AuraEnabled(cacheable=true)
    public static Boolean isReCreateFeatureBranchAvailable() {
        try {
            return !Personal_Settings__c.getInstance().Disable_Re_Create_Feature_Branch_in_US__c;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled
    public static JobExecution__c commitChanges(UserStoryCommitRequest request) {
        try {
            return CommitAction.commitChanges(new List<CommitAction.Request>{ request.parse() })[0].jobExecution;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<User_Story_Metadata__c> getUserStoryMetadata(String recordId) {
        try {
            return new UserStoriesMetadataSelector().byUserStoryId(new Set<Id>{ recordId });
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }
}