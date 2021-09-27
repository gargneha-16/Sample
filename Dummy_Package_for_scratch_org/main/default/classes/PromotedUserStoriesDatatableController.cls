public with sharing class PromotedUserStoriesDatatableController {

    // PUBLIC

    @AuraEnabled
    public static List<Promoted_User_Story__c> fetchData(String promotionId, String selectFieldSet) {
        try {
            return new PromotedUserStoriesSelector().byPromotionIdWithFields(new Set<Id>{ promotionId }, getProcessedFields(Promoted_User_Story__c.SObjectType, selectFieldSet));
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled
    public static List<User_Story__c> availableUserStories(String promotionId, String selectFieldSet) {
        List<User_Story__c> userStories = new List<User_Story__c>();
        Promotion__c promotion = promotionDetailsById(promotionId);
        Set<Id> alreadyAddedUserStoryIds = alreadyAddedUserStoryIds(new Set<Id>{ promotion.Id });
        Set<Id> projectIds = new Set<Id>{ promotion.Project__c };
        Set<Id> releaseIds = new Set<Id>{ promotion.Release__c };
        Set<Id> environmentIds = new Set<Id>{ promotion.Source_Environment__c };

        if (!promotion.Back_Promotion__c) {
            for(User_Story__c userStory : new UserStoriesSelector().readyToPromoteWithFields(getProcessedFields(User_Story__c.SObjectType, selectFieldSet), environmentIds, projectIds, releaseIds)) {
                if(!alreadyAddedUserStoryIds.contains(userStory.Id)) {
                    userStories.add(userStory);    
                }
            }
        } else {
            Id pipelineId = null;
            if(promotion.Project__c != null) {
                pipelineId = promotion.Project__r.Deployment_Flow__c;
            } else if(promotion.Release__c != null) {
                pipelineId = promotion.Release__r.Project__r.Deployment_Flow__c;
            }
            List<Deployment_Flow_Step__c> pipelineConnections = new DeploymentFlowStepsSelector().byPipelineAndSourceEnvironment(pipelineId, promotion.Destination_Environment__c);

            Set<Id> userStoryIds = new Set<Id>();
            if (!pipelineConnections.isEmpty()) {
                for (User_Story__c userStory : GlobalUtilities.getUserStoriesFromFieldsetBehind(getProcessedFields(User_Story__c.SObjectType, selectFieldSet), pipelineConnections.get(0))) {
                    userStoryIds.add(userStory.Id);
                }

                for(User_Story__c userStory : new UserStoriesSelector().readyToBackPromoteWithFields(getProcessedFields(User_Story__c.SObjectType, selectFieldSet), userStoryIds)) {
                    if(!alreadyAddedUserStoryIds.contains(userStory.Id) && (promotion.Project__c != null && promotion.Project__c == userStory.Project__c || promotion.Release__c != null && promotion.Release__c == userStory.Release__c)) {
                        userStories.add(userStory);    
                    }
                }
            }
        }

        return userStories;
    }

    @AuraEnabled
    public static void addSelectedUserStoriesToPromotion(String promotionId, List<Id> userStoryIds) {
        try { 
            List<Promotion__c> promotions = new PromotionsSelector().onlyPromotionsDetailByIds(new Set<Id>{ promotionId });
            Promotion__c promotion = promotions.isEmpty() ? new Promotion__c() : promotions[0];
            List<Promoted_User_Story__c> promotedUserStories = new List<Promoted_User_Story__c>();
            List<User_Story__c> userStories = new UserStoriesSelector().byIds(new Set<Id>(userStoryIds));

            for(User_Story__c userStory : userStories) {
                String promotedUserStoryName = promotion.Back_Promotion__c ? 'Back Promoted User Story: ' + userStory.Name : 'Promoted User Story: ' + userStory.Name;
                promotedUserStories.add(new Promoted_User_Story__c(Name = promotedUserStoryName, Promotion__c = promotion.Id, User_Story__c = userStory.Id));
            }

            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, promotedUserStories);
            insert decision.getRecords();
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }

    @AuraEnabled
    public static void removeSelectedPromotedUserStories(List<Id> promotedUserStoryIds) {
        try {
            if (!promotedUserStoryIds.isEmpty()) {
                List<Promoted_User_Story__c> promotedUserStories = [SELECT Id FROM Promoted_User_Story__c WHERE Id IN :promotedUserStoryIds WITH SECURITY_ENFORCED];
                Utilities.Secure_DML(promotedUserStories, Utilities.DML_Action.DEL, Schema.SObjectType.Promoted_User_Story__c);
            }
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }


    // PRIVATE 

    private static Promotion__c promotionDetailsById(Id promotionId) {
        List<Promotion__c> promotions = new PromotionsSelector().onlyPromotionsDetailByIds(new Set<Id>{ promotionId });
        return promotions.isEmpty() ? new Promotion__c() : promotions[0];
    }

    private static Set<Id> alreadyAddedUserStoryIds(Set<Id> promotionIds) {
        Set<Id> result = new Set<Id>();
        for(Promoted_User_Story__c promotedUserStories : new PromotedUserStoriesSelector().byPromotionId(promotionIds)) {
            result.add(promotedUserStories.User_Story__c);
        }
        return result;
    }

    private static Set<String> getProcessedFields(SObjectType objectType, String fieldSet) {
        Set<String> result = new Set<String>();
        for (FieldSetMember field : getFieldSetFields(objectType, fieldSet)) {
            String fieldToAdd = field.getFieldPath();
            if (field.getType() == DisplayType.REFERENCE ) {
                if (field.getFieldPath().endsWith('__c')) {
                    fieldToAdd = field.getFieldPath().replace('__c', '__r.Name');
                } else if (field.getFieldPath().endsWith('Id')) {
                    // Trick to no to replace other possible appearances of 'Id' in the field name
                    fieldToAdd = field.getFieldPath() + '__';
                    fieldToAdd = fieldToAdd.replace('Id__', '.Name');
                }
            }
            result.add(fieldToAdd);
        }
        return result;
    }

    private static List<FieldSetMember> getFieldSetFields(SObjectType objectType, String fieldSet) {
        return fflib_SObjectDescribe.getDescribe(objectType).getFieldSets().get(fieldSet).getFields();
    }
}