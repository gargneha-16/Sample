@SuppressWarnings('PMD')
public with sharing class JobTemplateService extends PipelineOperationsHelper implements PipelineOperationsInterface {
    private PipelineManagerExtension.PipelineOperationsServiceJobsParameters innerJobParameters;
    private List<Promotion__c> promotions;
    private Set<Id> promotionIds;

    // PUBLIC

    public PipelineManagerExtension.PipelineOperationsServiceJobsResult validation(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters
    ) {
        result = new PipelineManagerExtension.PipelineOperationsServiceJobsResult();
        return result;
    }

    public PipelineManagerExtension.PipelineOperationsServiceJobsResult createPromotionAndPromotedUserStories(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters
    ) {
        overlayWrapperRecord = jobParameters.overlayWrapperRecord;
        testLevelValue = jobParameters.testLevelValue;
        result = new PipelineManagerExtension.PipelineOperationsServiceJobsResult();
        insertPromotionAndRelations();
        return result;
    }

    public PipelineManagerExtension.PipelineOperationsServiceJobsResult promoteAndDeploy(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters
    ) {
        createPromotionAndPromotedUserStories(jobParameters);
        jobParameters.promotionWrappers = result.promotionWrappers;
        try {
            return commonOperations(jobParameters, true, true);
        } catch (Exception ex) {
            throw new PipelineOperationsHelperException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    public PipelineManagerExtension.PipelineOperationsServiceJobsResult deploy(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters
    ) {
        result = new PipelineManagerExtension.PipelineOperationsServiceJobsResult();
        try {
            return commonOperations(jobParameters, false, true);
        } catch (Exception ex) {
            throw new PipelineOperationsHelperException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    public PipelineManagerExtension.PipelineOperationsServiceJobsResult commonOperations(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters,
        Boolean isPromoteAndDeploy,
        Boolean checkPromotionStatus
    ) {
        innerJobParameters = jobParameters;
        updatePromotions();
        promotions = new PromotionsSelector().onlyPromotionsDetailByIds(promotionIds);
        // Agreed with Nahuel that it will be inside for loop, since each call will be async there will be no problem
        for (Promotion__c promotionRecord : promotions) {
            request(promotionRecord.Id, true, isPromoteAndDeploy, false);
        }

        populateVariables();
        if(checkPromotionStatus) {
            checkPromotionsStatuses();
            result.enabledPromotionBackPromotionPoller = true;
        }
        return result;
    }


    // PRIVATE

    private void insertPromotionAndRelations() {
        promotionByUserStoryReleases = new Map<String, Promotion__c>();
        List<Promotion__c> promotions = new List<Promotion__c>();
        selectedUserStories = new List<User_Story__c>();

        Boolean isBackPromotion = overlayWrapperRecord.pathType.toLowerCase() == C_PULL;

        Set<Id> usIds = new Set<Id>();
        for (BranchManagementExtension.UserStoryWrapper userStoryWrapperItem : overlayWrapperRecord.userStories) {
            usIds.add(userStoryWrapperItem.userStory.Id);
        } 
        Map<Id, User_Story__c> userStoriesByIds = new UserStoriesSelector().byUserStoryIds(usIds);

        for (BranchManagementExtension.UserStoryWrapper userStoryWrapperItem : overlayWrapperRecord.userStories) {
            if (userStoryWrapperItem.isSelected) {
                selectedUserStories.add(userStoryWrapperItem.userStory);
                if (!promotionByUserStoryReleases.containsKey(userStoryWrapperItem.userStory.Release__c)) {
                    User_Story__c userStory = userStoriesByIds.get(userStoryWrapperItem.userStory.Id);
                    String projectId = String.isNotBlank(userStory.Project__c) ? userStory.Project__c : userStory.Release__r.Project__c;
                    PromoteAction.Request request = new PromoteAction.Request();
                    request.sourceEnvironmentId = isBackPromotion ? overlayWrapperRecord.toEnvId : userStory.Environment__c;
                    request.projectId = projectId;
                    request.isBackPromotion = isBackPromotion;
                    // TODO for now check promotions per project but later it will change with release
                    promotionByUserStoryReleases.put(projectId, PromoteAction.createPromotionRecord(request));
                }
            }
        }

        if (selectedUserStories.isEmpty()) {
            throw new PipelineOperationsHelperException(Label.CBM2_at_least1_us);
        }

        try {
            promotions = promotionByUserStoryReleases.values();
            if(!promotions.isEmpty()) {
                promotions =  PromoteAction.insertPromotions(promotions);
            }

            Set<Id> promotionIds = new Set<Id>();
            for (Promotion__c promotionRecord : promotions) {
                promotionByUserStoryReleases.put(promotionRecord.Project__c, promotionRecord);
                promotionIds.add(promotionRecord.Id);
            }
            
            List<Promoted_User_Story__c> promotedUserStories = new List<Promoted_User_Story__c>();
            for (User_Story__c userStoryRecord : selectedUserStories) {
                User_Story__c tempUserStoryRecord = userStoriesByIds.get(userStoryRecord.Id);
                String projectId = String.isNotBlank(tempUserStoryRecord.Project__c) ? tempUserStoryRecord.Project__c : tempUserStoryRecord.Release__r.Project__c;
                Promotion__c promotion = promotionByUserStoryReleases.get(projectId);
                promotedUserStories.add(PromoteAction.createPromotedUserStoryRecord(promotion, tempUserStoryRecord));
            }
            PromoteAction.insertPromotedUserStories(promotedUserStories);

            // Agreed with Nahuel that it will be inside for loop, since each call will be async there will be no problem
            for (Promotion__c promotionRecord : promotions) {
                request(promotionRecord.Id, false, false, false);
            }

            getPendingPromotions(promotionIds);
        } catch (Exception ex) {
            throw new PipelineOperationsHelperException(ex.getMessage() + ex.getStackTraceString());
        }
    }

    private void updatePromotions() {
        promotions = new List<Promotion__c>();
        promotionIds = new Set<Id>();
        for (PipelineManagerExtension.PromotionWrapper promotionItem : innerJobParameters.promotionWrappers) {
            if (promotionItem.isSelected && promotionItem.promotion.Status__c != COMPLETED) {
                promotionItem.promotion.Status__c = IN_PROGRESS;
                promotions.add(promotionItem.promotion);
                promotionIds.add(promotionItem.promotion.Id);
            }
        }

        PromotionTriggerHelper.bypassPromotionTrigger = true;
        SObjectAccessDecision promotionDecision = Security.stripInaccessible(AccessType.UPDATABLE, promotions);
        update promotionDecision.getRecords();
        promotions.clear();
    }

    private void populateVariables() {
        testLevelValuesByPromotionIds = new Map<String, String>();
        for (Promotion__c promotionRecord : promotions) {
            testLevelValuesByPromotionIds.put(promotionRecord.Id, '');
        }
    }

    private void request(String promotionId, Boolean executePromotion, Boolean executeDeployment, Boolean deploymentDryRun) {
        List<PromoteAction.Request> requests = new List<PromoteAction.Request>();
        PromoteAction.Request request = new PromoteAction.Request();
        request.promotionId = promotionId;
        request.executePromotion = executePromotion;
        request.executeDeployment = executeDeployment;
        request.deploymentDryRun = deploymentDryRun;
        requests.add(request);
        PromoteAction.promote(requests);
    }
}