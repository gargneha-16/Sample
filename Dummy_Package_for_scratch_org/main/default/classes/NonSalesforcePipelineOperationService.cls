public with sharing class NonSalesforcePipelineOperationService extends PipelineOperationsHelper implements PipelineOperationsInterface {
    private Map<Id, Id> newStepRecordIdsByOldStepRecordIds;

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
        preparePromotionAndRelations();
        return result;
    }

    public PipelineManagerExtension.PipelineOperationsServiceJobsResult promoteAndDeploy(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters
    ) {
        createPromotionAndPromotedUserStories(jobParameters);
        jobParameters.promotionWrappers = result.promotionWrappers;
        try {
            return commonOperations(jobParameters, true);
        } catch (Exception ex) {
            throw new PipelineOperationsHelperException(ex.getMessage());
        }
    }

    public PipelineManagerExtension.PipelineOperationsServiceJobsResult deploy(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters
    ) {
        result = new PipelineManagerExtension.PipelineOperationsServiceJobsResult();
        try {
            return commonOperations(jobParameters, false);
        } catch (Exception ex) {
            throw new PipelineOperationsHelperException(ex.getMessage());
        }
    }

    private PipelineManagerExtension.PipelineOperationsServiceJobsResult commonOperations(
        PipelineManagerExtension.PipelineOperationsServiceJobsParameters jobParameters,
        Boolean isPromoteAndDeploy
    ) {
        List<Promotion__c> promotions = new List<Promotion__c>();
        List<Deployment__c> deployments = new List<Deployment__c>();
        testLevelValuesByPromotionIds = new Map<String, String>();
        String destinationEnvironmentId = '';
        for (PipelineManagerExtension.PromotionWrapper promotionItem : jobParameters.promotionWrappers) {
            if (promotionItem.isSelected && promotionItem.promotion.Status__c != COMPLETED) {
                promotionItem.promotion.Status__c = SCHEDULED;
                promotions.add(promotionItem.promotion);
                testLevelValuesByPromotionIds.put(promotionItem.promotion.Id, '');
                if (String.isBlank(destinationEnvironmentId)) {
                    destinationEnvironmentId = promotionItem.promotion.Destination_Environment__c;
                }
            }
        }
        SObjectAccessDecision promotionDecision = Security.stripInaccessible(AccessType.UPDATABLE, promotions);
        update promotionDecision.getRecords();
        promotions.clear();
        promotions = [
            SELECT 
                Id, 
                Name, 
                Source_Org_Credential__c,
                Destination_Org_Credential__c,
                Destination_Environment__c,
                Destination_Environment__r.Name,
                Destination_Environment__r.Platform__c,
                Destination_Environment__r.Deployment_Automation_Override__c,
                Destination_Environment__r.Deployment_Automation_Override__r.Name,
                Destination_Environment__r.Promotion_Override__c,
                Destination_Environment__r.Promotion_Override__r.Name
            FROM Promotion__c
            WHERE Id IN :testLevelValuesByPromotionIds.keySet()
            WITH SECURITY_ENFORCED
        ];

        String targetCredentialId = promotions[0].Destination_Org_Credential__c;
        String deploymentTemplateId = promotions[0].Destination_Environment__r.Deployment_Automation_Override__c != null
            ? promotions[0].Destination_Environment__r.Deployment_Automation_Override__c
            : jobParameters.pipelineDeploymentAutomationTemplateId;
        String deploymentTemplateName = promotions[0].Destination_Environment__r.Deployment_Automation_Override__r.Name != null
            ? promotions[0].Destination_Environment__r.Deployment_Automation_Override__r.Name
            : jobParameters.pipelineDeploymentAutomationTemplateName;
        String promotionTemplateId = promotions[0].Destination_Environment__r.Promotion_Override__c != null
            ? promotions[0].Destination_Environment__r.Promotion_Override__c
            : jobParameters.pipelinePromotionAutomationTemplateId;
        String promotionTemplateName = promotions[0].Destination_Environment__r.Promotion_Override__r.Name != null
            ? promotions[0].Destination_Environment__r.Promotion_Override__r.Name
            : jobParameters.pipelinePromotionAutomationTemplateName;

        for (Promotion__c promotionRecord : promotions) {
            if (isPromoteAndDeploy) {
                deployments.add(prepareDeployment(promotionRecord, promotionTemplateId, promotionTemplateName, true));
                deployments.add(prepareDeployment(promotionRecord, deploymentTemplateId, deploymentTemplateName, false));
            } else {
                deployments.add(prepareDeployment(promotionRecord, promotionTemplateId, promotionTemplateName, false));
            }
        }

        SObjectAccessDecision deploymentDecision = Security.stripInaccessible(AccessType.CREATABLE, deployments);
        insert deploymentDecision.getRecords();
        deployments = (List<Deployment__c>) deploymentDecision.getRecords();

        if (isPromoteAndDeploy) {
            Map<Id, Id> deploymentIdsByTemplateIds = new Map<Id, Id>();
            for (Deployment__c deploymentRecord : deployments) {
                deploymentIdsByTemplateIds.put(deploymentRecord.Template__c, deploymentRecord.Id);
            }

            for (Deployment__c deploymentRecord : deployments) {
                if (deploymentRecord.Template__c == promotionTemplateId) {
                    deploymentRecord.Parent_Deployment__c = deploymentIdsByTemplateIds.get(deploymentTemplateId);
                }
            }
            deploymentDecision = Security.stripInaccessible(AccessType.UPDATABLE, deployments);
            update deploymentDecision.getRecords();
            deployments = (List<Deployment__c>) deploymentDecision.getRecords();
        }

        List<String> stepParentIds = new List<String>();
        stepParentIds.add(promotionTemplateId);
        if (isPromoteAndDeploy) {
            stepParentIds.add(deploymentTemplateId);
        }

        cloneSteps(stepParentIds, deployments);
        createDestinationOrgs(targetCredentialId, deployments);
        updateFirstDeploymentJobsStatusToInvokeDeployments(isPromoteAndDeploy);
        checkPromotionsStatuses();
        result.enabledPromotionBackPromotionPoller = true;
        return result;
    }

    private Deployment__c prepareDeployment(Promotion__c promotionRecord, String templateId, String templateName, Boolean doNotUpdatePromotion) {
        String advancedDeploymentRecordId = Schema.Sobjecttype.Deployment__c.getRecordTypeInfosByDeveloperName()
            .get('Advanced_multi_step')
            .getRecordTypeId();

        Deployment__c deploymentRecord = new Deployment__c();
        deploymentRecord.Name = Label.Execution_of + ' ' + templateName;
        deploymentRecord.RecordTypeId = advancedDeploymentRecordId;
        deploymentRecord.Template__c = templateId;
        deploymentRecord.From_Org__c = promotionRecord.Source_Org_Credential__c;
        deploymentRecord.Status__c = SCHEDULED;
        deploymentRecord.Promotion__c = promotionRecord.Id;
        deploymentRecord.Deployment_Completed_email_sent__c = false;
        deploymentRecord.Deployment_command_sent__c = null;
        deploymentRecord.Do_Not_Update_Promotion__c = doNotUpdatePromotion;
        deploymentRecord.Parent_Deployment__c = null;
        if (deploymentRecord.Schedule__c == DEPLOY_NOW) {
            deploymentRecord.Date__c = System.now();
        }
        return deploymentRecord;
    }

    private void cloneSteps(List<String> templateIds, List<Deployment__c> deployments) {
        List<Step__c> steps = Utilities.getStepsByDeploymentIds(templateIds);
        List<String> deploymentIds = new List<String>();
        List<Step__c> newSteps = new List<Step__c>();
        for (Deployment__c deploymentRecord : deployments) {
            for (Step__c stepRecord : steps) {
                if (deploymentRecord.Template__c == stepRecord.Deployment__c) {
                    Step__c newStep = stepRecord.clone();
                    newStep.Deployment__c = deploymentRecord.Id;
                    newStep.Status__c = NOT_STARTED;
                    newSteps.add(newStep);
                }
            }
            deploymentIds.add(deploymentRecord.Id);
        }

        fflib_SObjectDomain.getTriggerEvent(StepTriggerHandler.class).disableBeforeInsert();
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, newSteps);
        insert decision.getRecords();
        fflib_SObjectDomain.getTriggerEvent(StepTriggerHandler.class).enableBeforeInsert();
       
        newSteps = Utilities.getStepsByDeploymentIds(deploymentIds);

        newStepRecordIdsByOldStepRecordIds = new Map<Id, Id>();
        for (Step__c oldStepRecord : steps) {
            for (Step__c newStepRecord : newSteps) {
                if (oldStepRecord.Order__c == newStepRecord.Order__c && oldStepRecord.Deployment__c == newStepRecord.Deployment__r.Template__c) {
                    newStepRecordIdsByOldStepRecordIds.put(oldStepRecord.Id, newStepRecord.Id);
                }
            }
        }
        cloneAttachments();
    }

    private void cloneAttachments() {
        List<Attachment> newAttachments = new List<Attachment>();
        for (Attachment attachmentRecord : [
            SELECT Id, Body, Name, ContentType, IsPrivate, ParentId
            FROM Attachment
            WHERE ParentId = :newStepRecordIdsByOldStepRecordIds.keySet()
            WITH SECURITY_ENFORCED
        ]) {
            Attachment newAtachmentRecord = attachmentRecord.clone(false, false, false, false);
            newAtachmentRecord.ParentId = newStepRecordIdsByOldStepRecordIds.get(attachmentRecord.ParentId);
            newAttachments.add(newAtachmentRecord);
        }

        fflib_SObjectDomain.getTriggerEvent(AttachmentTriggerHandler.class).disableBeforeInsert();
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, newAttachments);
        insert decision.getRecords();
        fflib_SObjectDomain.getTriggerEvent(AttachmentTriggerHandler.class).enableBeforeInsert();
    }

    private void createDestinationOrgs(Id targetCredentialId, List<Deployment__c> deployments) {
        List<Destination_Org__c> destinationOrgs = new List<Destination_Org__c>();
        for (Deployment__c deploymentRecord : deployments) {
            Destination_Org__c destinationOrg = new Destination_Org__c();
            destinationOrg.Deployment__c = deploymentRecord.Id;
            destinationOrg.To_Org__c = targetCredentialId;
            destinationOrg.Status__c = NOT_STARTED;
            destinationOrgs.add(destinationOrg);
        }
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, destinationOrgs);
        insert decision.getRecords();
    }

    private void updateFirstDeploymentJobsStatusToInvokeDeployments(Boolean isPromoteAndDeploy) {
        List<Deployment_Job__c> deploymentJobsToBeUpdated;
        if (isPromoteAndDeploy) {
            deploymentJobsToBeUpdated = [
                SELECT Id, Status__c
                FROM Deployment_Job__c
                WHERE
                    Step__c IN :newStepRecordIdsByOldStepRecordIds.values()
                    AND Step__r.Order__c = 1
                    AND Step__r.Deployment__r.Parent_Deployment__c != null
                WITH SECURITY_ENFORCED
            ];
        } else {
            deploymentJobsToBeUpdated = [
                SELECT Id, Status__c
                FROM Deployment_Job__c
                WHERE
                    Step__c IN :newStepRecordIdsByOldStepRecordIds.values()
                    AND Step__r.Order__c = 1
                    AND Step__r.Deployment__r.Parent_Deployment__c = null
                WITH SECURITY_ENFORCED
            ];
        }
        for (Deployment_Job__c deploymentJobRecord : deploymentJobsToBeUpdated) {
            deploymentJobRecord.Status__c = IN_PROGRESS;
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, deploymentJobsToBeUpdated);
        update decision.getRecords();
    }

    public class FunctionStepAttachmentDetails {
        public String functionId { get; set; }
        public String functionApiName { get; set; }
        public List<Parameter> functionParameters { get; set; }
    }
}