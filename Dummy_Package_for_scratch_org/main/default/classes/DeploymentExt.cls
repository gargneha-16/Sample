global with sharing class DeploymentExt {
    private final String OK_STRING = 'OK';
    public Deployment__c deployment { get; set; }
    public Boolean sourceCredentialValidated { get; set; }
    public Boolean showError { get; set; }
    public Boolean showOptions { get; set; }
    public List<Map<String, String>> messagesQueue = new List<Map<String, String>>();
    public Boolean showOtherInformation { get; set; }
    public Boolean ccdEnabled { get; set; }
    public String selectedToOrg { get; set; }
    public Boolean isDeploymentModeNew { get; set; }
    public Boolean showStepsOnly { get; set; } // MY: Added for DX post SO job preview. Since we will use deployments as data load and post success jobs we need to display steps on DX operation panel.
    public Boolean historyVisible = false;
    public Destination_Org__c[] destinations { get; set; }
    public Step__c[] steps { get; set; }
    public Org__c fromOrg { get; set; }
    public Boolean orgFiltered { get; set; }
    public String metadata_url { get; set; }
    public String describe_url { get; set; }
    public String sobjects_url { get; set; }
    public String testquery_url { get; set; }
    public String users_url { get; set; }
    public String cancel_url { get; set; }
    public String custom_settings_url { get; set; }
    public String git_metadata_url { get; set; }
    public String quick_actions_url { get; set; }
    public String urlParameters { get; set; }
    public String herokuServer { get; set; }
    public Boolean isShareable { get; set; }
    private Set<String> destinationCredentialIds;

    public DeploymentExt(ApexPages.StandardController stdController) {
        if (!Test.isRunningTest()) {
            stdController.addFields(Utilities.getAllFields('Deployment__c').get(Label.FIELDS).split(','));
            stdController.addFields(
                new List<String>{
                    'From_Org__r.Disable_Validation__c',
                    'From_Org__r.Oauth_Signature__c',
                    'Promotion__r.Project__r.Deployment_Flow__c',
                    'Promotion__r.Release__r.Project__r.Deployment_Flow__c'
                }
            );
        }
        this.deployment = (Deployment__c) stdController.getRecord();

        initializeVariables();
        isLicenseEnabled();
        deploymentSourceCredentialValidation();
        setUrls();
        initializeDestinationCredentials();
        initializeDeploymentSteps();
    }

    private void initializeVariables() {
        showOptions = true;
        showError = false;
        sourceCredentialValidated = false;
        isDeploymentModeNew = String.isBlank(this.deployment.Id);
        destinations = new List<Destination_Org__c>{};
        steps = new List<Step__c>{};
        showOtherInformation = SObjectType.Deployment__c.fieldSets.CustomFields.getFields().size() > 0;
        Map<String, Schema.SObjectType> globalDescribeValuesOfDeploymentObject = Schema.getGlobalDescribe();
        isShareable = globalDescribeValuesOfDeploymentObject.containsKey('Deployment__Share');
        // MY: Added for DX post SO job preview. Since we will use deployments as data load and post success jobs we need to display steps on DX operation panel.
        String stepsOnlyParam = ApexPages.currentPage().getParameters().get('stepsOnly');
        showStepsOnly = String.isNotBlank(stepsOnlyParam);
    }

    private void isLicenseEnabled() {
        if (!LicenseHelper.actionIsLicenseEnabled('viewEditDeployment')) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.WARNING, Label.CE_License_Restriction.replace('__License__', Label.CCH_or_CCM_License))
            );
            showError = true;
            showOptions = false;
        }
    }

    private void deploymentSourceCredentialValidation() {
        if (!isDeploymentModeNew) {
            if (deployment.From_Org__c != null) {
                populateSourceCredentialRecord();
            }
        }
    }

    private void populateSourceCredentialRecord() {
        fromOrg = Utilities.getOrgById(deployment.From_Org__c);
        orgFiltered = String.isNotBlank(fromOrg.Metadata_Types__c);
        checkAndValidateSourceCredential();
    }

    private void checkAndValidateSourceCredential() {
        if ((fromOrg.Platform__c == null || fromOrg.Platform__c == 'Salesforce') && fromOrg.Validated_Status__c != OK_STRING) {
            sourceCredentialValidated = DeployAPI.validateOrg(fromOrg.Id);
            if (!sourceCredentialValidated) {
                addErrorMessagesToMessageQueueMap(Label.ORG_NOT_VALIDATED);
            }
        } else {
            sourceCredentialValidated = true;
        }
    }

    private void setUrls() {
        cancel_url = getCancelURL();
        urlParameters = '?nosid=1';
        herokuServer = Settings.server_url;
        String baseURL = herokuServer + '/json/v1/';
        git_metadata_url = baseURL + 'gitmetadata/{repositoryId}/{commitId}' + urlParameters + '&branch={branch}';
        if (deployment.From_Org__c == null) {
            return;
        }
        if (fromOrg != null && String.isNotBlank(fromOrg.Metadata_Types__c)) {
            urlParameters += '&filter=' + EncodingUtil.urlEncode(fromOrg.Metadata_Types__c, 'UTF-8');
        }
        String sourceCredentialEncoded = EncodingUtil.urlEncode(deployment.From_Org__c, 'UTF-8');
        metadata_url = baseURL + 'metadata/' + sourceCredentialEncoded + urlParameters + '&dates=format';
        describe_url = baseURL + 'describe/' + sourceCredentialEncoded + '/{sobject}' + urlParameters;
        sobjects_url = baseURL + 'listSObjects/' + sourceCredentialEncoded + urlParameters;
        testquery_url = baseURL + 'test-query/' + sourceCredentialEncoded + urlParameters;
        users_url = baseURL + 'users/' + sourceCredentialEncoded + urlParameters;
        custom_settings_url = baseURL + 'customSetting/' + sourceCredentialEncoded + '/{sobject}' + urlParameters;
        quick_actions_url = baseURL + 'quickActions/' + sourceCredentialEncoded + '/{sobject}' + urlParameters;
    }

    private String getCancelURL() {
        Schema.DescribeSObjectResult result = Deployment__c.SObjectType.getDescribe();
        return '/' + result.getKeyPrefix();
    }

    private void initializeDestinationCredentials() {
        destinationCredentialIds = new Set<String>();
        Set<String> destinationEnvironmentIds = new Set<String>();

        if (!isDeploymentModeNew) {
            destinations = CopadoAPI.getDestinationsOrg(this.deployment.Id);
            //pre-fill set helper in order to validate faster duplicates
            for (Destination_Org__c destinationCredentialRecord : destinations) {
                destinationCredentialIds.add(destinationCredentialRecord.To_Org__c);
                destinationEnvironmentIds.add(destinationCredentialRecord.To_Org__r.Environment__c);
            }
            if (destinations.size() == 1) {
                checkDestinationCredentialsForConnectionBehavior(destinationCredentialIds);
                checkPipelineConnectionForConnectionBehavior(destinationEnvironmentIds);
            }
        }
        if (destinations.isEmpty()) {
            addDestination();
        }
    }

    private void checkDestinationCredentialsForConnectionBehavior(Set<String> credentialIds) {
        for (Org__c credentialRecord : [
            SELECT Id, Environment__c, Environment__r.Connection_Behavior__c, Environment__r.Connection_Behavior__r.Promotion_Behavior__c
            FROM Org__c
            WHERE Id IN :credentialIds
            WITH SECURITY_ENFORCED
        ]) {
            Boolean credentialEnvironmentHasConnectionBehavior = null != credentialRecord.Environment__r.Connection_Behavior__c;
            Boolean connectionBehaviorHasPromotionBehavior = credentialRecord.Environment__r.Connection_Behavior__r.Promotion_Behavior__c != '';
            Boolean hasConnectionBehavior = credentialEnvironmentHasConnectionBehavior && connectionBehaviorHasPromotionBehavior;
            ccdEnabled = hasConnectionBehavior;
        }
    }

    private void checkPipelineConnectionForConnectionBehavior(Set<String> destinationEnvironmentIds) {
        if (null != deployment.Promotion__c & destinations.size() == 1) {
            Id pipelineId = null != deployment.Promotion__r.Project__c
                ? deployment.Promotion__r.Project__r.Deployment_Flow__c
                : deployment.Promotion__r.Release__r.Project__r.Deployment_Flow__c;
            for (Deployment_Flow_Step__c pipelineConnectionRecord : [
                SELECT Id, Connection_Behavior__c
                FROM Deployment_Flow_Step__c
                WHERE
                    Source_Environment__c = :deployment.Source_Environment__c
                    AND Destination_Environment__c IN :destinationEnvironmentIds
                    AND Deployment_Flow__c = :pipelineId
                WITH SECURITY_ENFORCED
            ]) {
                if (String.isNotBlank(pipelineConnectionRecord.Connection_Behavior__c)) {
                    ccdEnabled = true;
                }
            }
        }
    }

    public void addDestination() {
        destinations.add(new Destination_Org__c(Deployment__c = this.deployment.Id));
    }

    private void initializeDeploymentSteps() {
        if (!isDeploymentModeNew) {
            steps = CopadoAPI.listSteps(this.deployment.Id);
        }
    }

    public PageReference saveDeployment() {
        runNecessaryValidationBeforeSavingDeployment();
        if (!messagesQueue.isEmpty()) {
            return null;
        }

        try {
            SObjectAccessDecision deploymentDecision = Security.stripInaccessible(AccessType.UPSERTABLE, new List<Deployment__c>{ deployment });
            upsert deploymentDecision.getRecords();
            deployment = (Deployment__c) deploymentDecision.getRecords()[0];
            addSuccessMessageToMessageQueueMap(Label.Deployment_Saved);
            if (isDeploymentModeNew) {
                return new Apexpages.StandardController(deployment).view();
            }
        } catch (Exception ex) {
            addErrorMessagesToMessageQueueMap(ex.getMessage());
        }
        return null;
    }

    private void runNecessaryValidationBeforeSavingDeployment() {
        if (String.isNotBlank(deployment.From_Org__c) && !sourceCredentialValidated) {
            addErrorMessagesToMessageQueueMap(Label.WRONG_CREDENTIALS);
        }
        if (LicenseHelper.isLicensesExceeded()) {
            addErrorMessagesToMessageQueueMap(Label.LICENSES_EXCEEDED);
        }
        if (!LicenseHelper.isCopadoEnabled() && !isAttachDeploymentFileChanged()) {
            addErrorMessagesToMessageQueueMap(Label.COPADO_DEPLOYER_LICENSE_NOT_ENABLED);
        }
    }

    private Boolean isAttachDeploymentFileChanged() {
        Deployment__c oldDeploymentRecord = [
            SELECT Id, Name, Attach_Deployment_File__c, Send_Deployment_Complete_email__c, From_Org__c
            FROM Deployment__c
            WHERE Id = :deployment.Id
            WITH SECURITY_ENFORCED
        ];
        return (deployment.Name == oldDeploymentRecord.Name &&
        deployment.Send_Deployment_Complete_email__c == oldDeploymentRecord.Send_Deployment_Complete_email__c &&
        deployment.From_Org__c == oldDeploymentRecord.From_Org__c &&
        deployment.Attach_Deployment_File__c != oldDeploymentRecord.Attach_Deployment_File__c);
    }

    private void addErrorMessagesToMessageQueueMap(String message) {
        addMessageToQueueMap('ERROR', message);
    }

    private void addSuccessMessageToMessageQueueMap(String message) {
        addMessageToQueueMap('CONFIRM', message);
    }

    private void addMessageToQueueMap(String type, String message) {
        //we are using this map in order to save messages from apex
        //and then render them as a json object in order to be used by the JSApp
        Map<String, String> messagesByMessageType = new Map<String, String>();
        messagesByMessageType.put('s', type);
        messagesByMessageType.put('m', message);

        messagesQueue.add(messagesByMessageType);
    }

    public PageReference validateFromOrg() {
        PageReference pReference = null;
        if (deployment.From_Org__c == null) {
            fromOrg = null;
            return pReference;
        }

        populateSourceCredentialRecord();

        if (sourceCredentialValidated) {
            pReference = saveDeployment();
            setUrls();
        }
        return pReference;
    }

    public void saveDestination() {
        Destination_Org__c newDestinationCredential = new Destination_Org__c();
        for (Destination_Org__c destinationCredentialRecord : destinations) {
            if (String.isBlank(destinationCredentialRecord.Id)) {
                newDestinationCredential = destinationCredentialRecord;
                break;
            }
        }

        destinationCredentialNecessaryValidations(newDestinationCredential);
        if (!messagesQueue.isEmpty()) {
            return;
        }

        Org__c org = Utilities.getOrgById(newDestinationCredential.To_Org__c);
        if ((org.Platform__c == null || org.Platform__c == 'Salesforce') && org.Validated_Status__c != OK_STRING) {
            if (!DeployAPI.validateOrg(org.Id)) {
                addErrorMessagesToMessageQueueMap(Label.DESTINATION_ORG_NOT_VALIDATED);
                return;
            }
        }
        CopadoAPI.addDestinationOrg(this.deployment.Id, newDestinationCredential.To_Org__c);
        initializeDestinationCredentials();
        addSuccessMessageToMessageQueueMap(Label.DESTINATION_ORG_SAVED);
    }

    private void destinationCredentialNecessaryValidations(Destination_Org__c destinationCredentialRecord) {
        if (String.isBlank(destinationCredentialRecord.To_Org__c)) {
            addErrorMessagesToMessageQueueMap(Label.ORG_NOT_VALIDATED);
        }
        if (destinationCredentialIds.contains(destinationCredentialRecord.To_Org__c)) {
            addErrorMessagesToMessageQueueMap(Label.DESTINATION_ORG_ALREADY_SELECTED);
        }
    }

    public PageReference deleteDestOrg() {
        ccdEnabled = false;
        CopadoAPI.removeDestinationOrg(this.deployment.Id, selectedToOrg);
        initializeDestinationCredentials();
        return null;
    }

    public String getDestinationsJson() {
        return JSON.serialize(this.destinations);
    }

    public String getStepsJson() {
        return JSON.serialize(this.steps);
    }

    public String getDepJson() {
        return JSON.serialize(this.deployment);
    }

    public String getjsonMessagesQueue() {
        return JSON.serialize(this.messagesQueue);
    }

    @RemoteAction
    global static void sortSteps(String[] ids) {
        List<Step__c> steps = new List<Step__c>();
        Integer index = 1;
        for (String stepId : ids) {
            steps.add(new Step__c(Id = stepId, Order__c = index));
            index++;
        }

        SObjectAccessDecision stepDecision = Security.stripInaccessible(AccessType.UPSERTABLE, steps);
        upsert stepDecision.getRecords();
        steps = (List<Step__c>) stepDecision.getRecords();
    }

    @RemoteAction
    global static void deleteStep(String stepId) {
        if (String.isNotBlank(stepId)) {
            CopadoAPI.removeStep(stepId);
        }
    }

    public Boolean getHistoryVisible() {
        return Schema.SObjectType.Deployment_History__c.fields.Deployment__c.isAccessible();
    }

    public String getJobsManagerMatchingKey() {
        String matchingKey = '', flow_id = '', target_branch = '';
        Step__c gitPromotionStep = null;
        for (Step__c stepRecord : steps) {
            if (stepRecord.Type__c == 'Git Promotion') {
                gitPromotionStep = stepRecord;
                break;
            }
        }
        if (gitPromotionStep == null) {
            return '';
        }
        try {
            for (Attachment att : [
                SELECT Id, Body
                FROM Attachment
                WHERE ParentId = :gitPromotionStep.Id AND Name = 'Git-Promotion.json'
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 1
            ]) {
                Map<String, Object> contents = (Map<String, Object>) JSON.deserializeUntyped(att.Body.toString());
                flow_id = (String) contents.get('flow_id');
                target_branch = (String) contents.get('target_branch');
                break;
            }

            if (String.isNotBlank(flow_id) && String.isNotBlank(target_branch)) {
                for (Deployment_Flow__c df : [SELECT Git_Repository__c FROM Deployment_Flow__c WHERE Id = :flow_id WITH SECURITY_ENFORCED LIMIT 1]) {
                    matchingKey = 'GIT-' + df.Git_Repository__c + '-' + target_branch;
                    break;
                }
            }
        } catch (Exception ex) {
            addErrorMessagesToMessageQueueMap(ex.getMessage());
        }
        return matchingKey;
    }

    public static Boolean getisChatterEnabled() {
        return Schema.SObjectType.User.isFeedEnabled() && Schema.SObjectType.Deployment__c.isFeedEnabled();
    }
}