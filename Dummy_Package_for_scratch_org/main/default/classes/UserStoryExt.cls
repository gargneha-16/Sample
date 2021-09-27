public with sharing class UserStoryExt {
    public User_Story__c userStory { get; set; }
    public String userStoriesAheadBehindTitle { get; set; }
    private String namespace;

    public UserStoryExt(ApexPages.StandardController stdController) {
        isLicenseAndFeatureEnabled();
        namespace = Settings.ns;
        if(!Test.isRunningTest()) {
            stdController.addFields(new List<String>{
                    namespace + 'Base_Branch__c', namespace + 'Project__r.' + namespace + 'Deployment_Flow__c', namespace + 'Release__r.' + namespace + 'Project__r.' + namespace + 'Deployment_Flow__c', namespace + 'Release__r.' + namespace + 'Base_Branch__c', namespace + 'Environment__r.Name', namespace + 'Org_Credential__r.' + namespace + 'Org_Type__c'
            });
        }
        this.userStory = (User_Story__c) stdController.getRecord();
        Id userStoryId = userStory?.Id;
        if (userStoryId != null) {
            checkForLastCommitNoChanges(userStoryId);
            checkDataCommitsStatus(userStoryId);
        }
    }

    public void isLicenseAndFeatureEnabled() {
        if (!LicenseHelper.actionIsLicenseEnabled('viewUserStoryPage')) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.WARNING, Label.CE_License_Restriction.replace('__License__', Label.CCM_or_CAD_License))
            );
        }
        if (!FeatureHelper.isChangeChangeManagementEnabled()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, Label.Change_Management_Feature_Not_Enabled));
        }
        return;
    }

    public List<GlobalUtilities.flowStepWrapper> getDeploymentFlowSteps() {
        List<GlobalUtilities.flowStepWrapper> visualFlowSteps = GlobalUtilities.getDeploymentFlowSteps(userStory);
        userStoriesAheadBehindTitle = GlobalUtilities.userStoriesAheadBehindTitle;
        if (visualFlowSteps.isEmpty() && String.isNotBlank(userStory.Org_Credential__c) && String.isNotBlank(userStory.Project__c)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, Label.Org_Credential_Not_Included_In_Deployment_Flow));
        }
        return visualFlowSteps;
    }

    private void checkForLastCommitNoChanges(Id usId) {
        if (Schema.SObjectType.User_Story_Commit__c.isAccessible() && Schema.SObjectType.User_Story_Commit__c.isQueryable()) {
            List<User_Story_Commit__c> commits = [
                SELECT Id, Snapshot_Commit__r.Status__c
                FROM User_Story_Commit__c
                WHERE User_Story__c = :usId
                ORDER BY Snapshot_Commit__r.Commit_Date__c DESC
                LIMIT 1
            ];
            if (!commits.isEmpty()) {
                if (commits[0].Snapshot_Commit__r.Status__c == 'No changes') {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, Label.COMMIT_NO_CHANGES));
                }
            }
        } else {
            UIDesignHelper.warningMessageOLSFLS(Schema.SObjectType.User_Story_Commit__c.label);
        }
    }

    private void checkDataCommitsStatus(Id userStoryId) {
        if (Schema.SObjectType.User_Story_Data_Commit__c.isAccessible() && Schema.SObjectType.User_Story_Data_Commit__c.isQueryable()) {
            Map<Id, List<User_Story_Data_Commit__c>> dataCommitsByDataSet = new UserStoryDataCommitsSelector()
                .byUserStoryGroupByDataSet(new Set<Id>{ userStoryId })
                .get(userStoryId);

            for (Id dataSetId : dataCommitsByDataSet.keySet()) {
                // Note: we are sorting data commits by descending date
                List<User_Story_Data_Commit__c> dataSetDataCommits = dataCommitsByDataSet.get(dataSetId);

                for (User_Story_Data_Commit__c dataCommit : dataSetDataCommits) {
                    if (isRunningCommit(dataCommit)) {
                        continue;
                    }
                    if (isFailedCommit(dataCommit)) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, Label.DataCommitNoChanges));
                        break;
                    }
                    if (isSuccessCommit(dataCommit)) {
                        break;
                    }
                }
            }
        } else {
            UIDesignHelper.warningMessageOLSFLS(Schema.SObjectType.User_Story_Data_Commit__c.label);
        }
    }

    private Boolean isRunningCommit(User_Story_Data_Commit__c dataCommit) {
        return dataCommit.Status__c == 'Draft' || dataCommit.Status__c == 'Scheduled' || dataCommit.Status__c == 'In progress';
    }

    private Boolean isFailedCommit(User_Story_Data_Commit__c dataCommit) {
        return dataCommit.Status__c == 'Cancelled' || dataCommit.Status__c == 'Completed with Errors' || dataCommit.Status__c == 'Merge Conflict';
    }

    private Boolean isSuccessCommit(User_Story_Data_Commit__c dataCommit) {
        return dataCommit.Status__c == 'Completed Successfully';
    }
}