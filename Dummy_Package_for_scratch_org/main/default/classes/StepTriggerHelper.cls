public without sharing class StepTriggerHelper {
    private static final String NAMESPACE = Settings.ns;

    private List<Step__c> steps;

    // CONSTRUCTOR

    public StepTriggerHelper(List<Step__c> steps) {
        this.steps = steps;
    }

    // PUBLIC

    public void notifyManualStepOwner() {
        for(Step__c step : steps) {
            if (isManualTaskInProgress(step)) {
                notifyTaskOwner(step);
            }
        }
    }

    public void validate() {
        checkFeature();

        // Note: Skip license check for Automated process
        if (UserInfo.getUserType() != 'AutomatedProcess') {
            checkLicense();
        }
    }

    public void afterInsert() {
        DeployJobHelper.upsertDeployJobs( getDeployments() );
    }

    // PRIVATE

    private Boolean isManualTaskInProgress(Step__c step) {
        return (
            step.Status__c == 'In Progress' &&
            step.Type__c == 'Manual Task' &&
            !step.Manual_Task_Notified__c
        );
    }

    private List<Deployment__c> getDeployments() {
        List<Deployment__c> result = new List<Deployment__c>();

        for (Step__c step : steps) {
            result.add(new Deployment__c(Id = step.Deployment__c));
        }

        return result;
    }


    private void checkFeature() {
        for (Step__c step : steps) {
            String feature = step.Type__c + ' step';
            Feature__c featureRecord = Feature__c.getValues(feature);

            if (featureRecord != null && !featureRecord.Enabled__c) {
                step.addError(Label.STEP_NOT_SUPPORTED);
            }
        }
    }

    private void checkLicense() {
        Boolean isLicensesExceeded = LicenseHelper.isLicensesExceeded();
        Boolean isCopadoEnabled = LicenseHelper.isCopadoEnabled();
        Boolean isCCMEnabled = LicenseHelper.isCCMEnabled();

        for (Step__c step : steps) {
            if (isLicensesExceeded) {
                step.addError(Label.LICENSES_EXCEEDED);
            }
            else if (!isCopadoEnabled && !isCCMEnabled) {
                step.addError(Label.COPADO_DEPLOYER_LICENSE_NOT_ENABLED);
            }
        }
    }

    private static void notifyTaskOwner(Step__c step) {
        step.Manual_Task_Notified__c = true;

        ManualTaskJSONdata taskData = (ManualTaskJSONdata) JSON.deserialize(step.dataJson__c, ManualTaskJSONdata.class);
        String chatterMessage = ' ' + System.Label.MANUAL_TASK_WAITING + ' ' + step.Name;

        // TODO: Bulkify send email part
        if (String.isEmpty(taskData.Task_Owner)) {
            return;
        }

        if ((taskData.Notify_Task_Owner == 'Chatter' || taskData.Notify_Task_Owner == 'Chatter and Email') &&
            Utilities.isChatterEnabled(NAMESPACE + 'Deployment__c')) {
            Utilities.notifyUsingChatterWithAtMention(taskData.Task_Owner, chatterMessage, step.Deployment__c);
        }

        if (taskData.Notify_Task_Owner == 'Email' || taskData.Notify_Task_Owner == 'Chatter and Email') {
            notifyUsingEmail(taskData.Task_Owner, step.Name, step.Deployment__c);
        }
    }

    // Note: User is a special object and non-admin users will not have access to it
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void notifyUsingEmail(String userId, String stepName, Id deploymentId) {
        User ownerOfTask = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.toAddresses = new List<String>{ ownerOfTask.Email };
        String htmlBody = System.Label.MANUAL_TASK_WAITING + ' ' + stepName + '<br/>';
        htmlBody += 'Deployment link: ' + Url.getSalesforceBaseUrl().toExternalForm() + '/' + deploymentId;
        message.setHtmlBody(htmlBody);
        message.setSubject(System.Label.MANUAL_TASK_WAITING + ' ' + stepName);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
    }

    // INNER

    // Note: needs to look exactly like the API JSON
    @SuppressWarnings('PMD.PropertyNamingConventions')
    private class ManualTaskJSONdata {
        public Boolean Perform_in_Destination_Org { get; set; }
        public Boolean Perform_in_Source_Org { get; set; }
        public String Task_Description { get; set; }
        public String Task_Owner { get; set; }
        public String Notify_Task_Owner { get; set; }
    }
}