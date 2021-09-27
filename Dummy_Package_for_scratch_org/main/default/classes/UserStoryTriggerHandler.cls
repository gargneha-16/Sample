/* Note: As we are implementing ITrigger, it is mandatory to mention all methods even if respective trigger events are not added in trigger.*/
@SuppressWarnings('PMD.EmptyStatementBlock')
public without sharing class UserStoryTriggerHandler implements ITrigger {
    public UserStoryTriggerHandler() {
    }

    public void bulkBefore() {
        UserStoryTriggerHelper.prepareMaps();
    }



    /**
     * Modifier is set to private after checking that it was not being referenced anywhere else,
     * so that way the scope of the method funcionality can be reduced and more clear
     */
    private void beforeCommon(SObject oldSo, SObject so) {
        UserStoryTriggerHelper.setProject((User_Story__c) so);
        UserStoryTriggerHelper.setEnvironment((User_Story__c) so);
        UserStoryTriggerHelper.validateOrgEnvironmentRelationship((User_Story__c) so);
        UserStoryTriggerHelper.checkSprints((User_Story__c) oldSo, (User_Story__c) so);
        UserStoryTriggerHelper.setOrderBeforeUpdate((User_Story__c) oldSo, (User_Story__c) so);
    }

    public void beforeInsert(SObject so) {
        beforeCommon(null, so);
    }

    public void beforeUpdate(SObject oldSo, SObject so) {
        beforeCommon(oldSo, so);
        UserStoryTriggerHelper.setChildPromotedUserStoriesAsOutdated((User_Story__c) oldSo, (User_Story__c) so);

        UserStoryTriggerHelper.addChangedBundleStory((User_Story__c) so, (User_Story__c) oldSo);
        UserStoryTriggerHelper.onCancel((User_Story__c) so, (User_Story__c) oldSo);

    }

    public void beforeDelete(SObject so) {
    }

    public void bulkAfter() {
        if (Trigger.isUpdate) {
            UserStoryTriggerHelper.groupChildToBundleStory();
        }
    }

    public void afterInsert(SObject so) {
        afterCommon(null, so);
    }

    public void afterUpdate(SObject oldSo, SObject so) {
        afterCommon(oldSo, so);
        UserStoryTriggerHelper.addUserStoryToPromoteDeployQueue((User_Story__c) oldSo, (User_Story__c) so);
        UserStoryTriggerHelper.stopIndexingMetadata((User_Story__c) oldSo, (User_Story__c) so);

        UserStoryTriggerHelper.updateBundleChildStories((User_Story__c) so, (User_Story__c) oldSo);

    }

    public void afterDelete(SObject so) {
        afterCommon(null, so);
    }

    public void afterUndelete(SObject so) {
        afterCommon(null, so);
    }

    public void andFinally() {

        if (Trigger.isUpdate) {
            if (Trigger.isBefore) {
                UserStoryTriggerHelper.validateIfBundleChild(Trigger.newMap);
            }
            if (Trigger.isAfter) {
                UserStoryTriggerHelper.promoteAndDeployUserStories();
                UserStoryTriggerHelper.executeBundleCancel();
                UserStoryTriggerHelper.executeBundleChildUpdate();
            }

        }
        if (Trigger.isAfter) {
            UserStoryTriggerHelper.updateSprintVelocity();
        }
        UserStoryTriggerHelper.executeIndexMetadataJob();
        UserStoryTriggerHelper.updateOutdatedPromotedUserStories();
    }

    // PRIVATE

    private void afterCommon(SObject oldSo, SObject so) {
        UserStoryTriggerHelper.getSprintVelocity(oldSo, so);
    }
}