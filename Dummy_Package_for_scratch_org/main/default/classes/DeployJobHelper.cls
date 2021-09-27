public with sharing class DeployJobHelper {
    private static final String COMPLETED_WITH_ERRORS = 'Completed with Errors';
    private static final String COMPLETED_SUCCESSFULLY = 'Completed Successfully';
    private static final String SUCCESS = 'Success';
    private static final String FAILED = 'Failed';
    private static final String CANCELLED = 'Cancelled';
    private static final String PENDING = 'Pending';
    private static final String NOT_STARTED = 'Not started';
    private static final String IN_PROGRESS = 'In progress';

    public static void upsertDeployJobs(List<Deployment__c> deployments) {
        Map<Id, Deployment__c> deploymentByIds = new DeploymentsSelector().deploymentByIds(deployments);
        List<Deployment_Job__c> deploymentJobs = new List<Deployment_Job__c>();
        List<Step__c> steps = new List<Step__c>();
        List<Destination_Org__c> destinationOrgs = new List<Destination_Org__c>();
        for (Deployment__c deployment : deploymentByIds.values()) {
            steps.addAll(deployment.Steps__r);
            destinationOrgs.addAll(deployment.Destination_Orgs__r);
        }

        for (Step__c step : steps) {
            for (Destination_Org__c destinationCredential : destinationOrgs) {
                if (step.Deployment__c == destinationCredential.Deployment__c) {
                    deploymentJobs.add(
                        new Deployment_Job__c(
                            Step__c = step.Id,
                            Destination_Org__c = destinationCredential.Id,
                            External_Id__c = step.Id + '_' + destinationCredential.Id
                        )
                    );
                }
            }
        }
        try {
            Utilities.Secure_DML(
                deploymentJobs,
                Utilities.DML_Action.UPS,
                schema.Sobjecttype.Deployment_Job__c,
                schema.sObjectType.Deployment_Job__c.fields.external_id__c
            );
        } catch (DmlException e) {
            //If we are in visualforce context
            if (ApexPages.currentPage() != null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, '' + e));
            }
        }
    }

    public static Map<Id, String> updateStatus(
        Map<Id, List<Deployment_Job__c>> deploymentJobsByDeploymentIds,
        List<Deployment_Job__c> deploymentJobs
    ) {
        Map<String, String> destinationOrgStatusByIds = getDestinationOrgStatus(deploymentJobs);
        Map<Id, Destination_Org__c> destinationOrgsByIds = new Map<Id, Destination_Org__c>();
        Map<Id, Step__c> stepsByIds = new Map<Id, Step__c>();
        Map<Id, Deployment__c> deploymentsByIds = new Map<Id, Deployment__c>();
        Map<Id, String> deploymentStatusesByIds = new Map<Id, String>();
        Map<Id, List<Deployment_Job__c>> deploymentJobsBySteps = new Map<Id, List<Deployment_Job__c>>();
        Set<Id> completedStepIds = new Set<Id>();
        Set<Id> failedStepIds = new Set<Id>();

        for (Deployment_Job__c deploymentJobRecord : deploymentJobs) {
            if(deploymentJobsBySteps.containsKey(deploymentJobRecord.Step__c)) {
                deploymentJobsBySteps.get(deploymentJobRecord.Step__c).add(deploymentJobRecord);
            } else {
                deploymentJobsBySteps.put(deploymentJobRecord.Step__c, new List<Deployment_Job__c> { deploymentJobRecord });
            }
        }

        for(Id stepId : deploymentJobsBySteps.keySet()) {
            Integer stepJobCount = deploymentJobsBySteps.get(stepId).size();
            Integer successJobCount = 0;
            Integer failedJobCount = 0;

            for(Deployment_Job__c deploymentJobRecord : deploymentJobsBySteps.get(stepId)) {
                if(deploymentJobRecord.Status__c == SUCCESS) {
                    successJobCount++;
                }
                if(deploymentJobRecord.Status__c == FAILED) {
                    failedJobCount++;
                }
            }

            if(stepJobCount == successJobCount) {
                completedStepIds.add(stepId);
            }

            Integer totalJobCount = failedJobCount + successJobCount;
            if(failedJobCount == stepJobCount || (stepJobCount == totalJobCount && totalJobCount != successJobCount)) {
                failedStepIds.add(stepId);
            }
        }

        for (Id deploymentId : deploymentJobsByDeploymentIds.keySet()) {
            for (Deployment_Job__c deploymentJob : deploymentJobsByDeploymentIds.get(deploymentId)) {
                //define status of the destination org
                String key = deploymentJob.Id + '_' + deploymentJob.Destination_org__c;
                Destination_Org__c destinationOrg = new Destination_Org__c(
                    Id = deploymentJob.Destination_org__c,
                    Status__c = destinationOrgStatusByIds.get(key)
                );
                destinationOrgsByIds.put(destinationOrg.Id, destinationOrg);

                //define status of the step
                Step__c step = new Step__c(Id = deploymentJob.Step__c);
                String newStepStatus = '';
                for (Deployment_Job__c deploymentJobRecord : deploymentJobs) {
                    if (deploymentJobRecord.Step__c == deploymentJob.Step__c) {
                        if (deploymentJobRecord.Status__c == PENDING || 
                            deploymentJobRecord.Status__c.toLowerCase() == IN_PROGRESS.toLowerCase() || 
                            (!failedStepIds.contains(deploymentJob.Step__c) && !completedStepIds.contains(deploymentJob.Step__c) && (deploymentJobRecord.Status__c == SUCCESS || deploymentJobRecord.Status__c == FAILED))) {
                            Boolean inProgressStatus = (deploymentJobRecord.Status__c == SUCCESS && !completedStepIds.contains(deploymentJob.Step__c)) || (deploymentJobRecord.Status__c == FAILED && !failedStepIds.contains(deploymentJob.Step__c));
                            newStepStatus = inProgressStatus ? IN_PROGRESS : destinationOrgStatusByIds.get(key);
                            break;
                        } else if (deploymentJobRecord.Status__c == SUCCESS && completedStepIds.contains(deploymentJob.Step__c)) {
                            newStepStatus = COMPLETED_SUCCESSFULLY;
                        } else if (deploymentJobRecord.Status__c == FAILED && failedStepIds.contains(deploymentJob.Step__c)) {
                            newStepStatus = COMPLETED_WITH_ERRORS;
                        } else if (deploymentJobRecord.Status__c == CANCELLED) {
                            newStepStatus = CANCELLED;
                            break;
                        }
                    }
                }
                if (String.isNotBlank(newStepStatus)) {
                    step.Status__c = newStepStatus;
                }
                stepsByIds.put(step.Id, step);

                //define status of the deployment
                Deployment__c deployment = new Deployment__c(Id = deploymentId);
                String newDeploymentStatus = '';
                Boolean isAllcompleted = true;
                Boolean isCancelled = false;
                for (String keyValue : destinationOrgStatusByIds.keySet()) {
                    String destinationOrgStatus = destinationOrgStatusByIds.get(keyValue);
                    if(keyValue.contains(deploymentJob.Id)) {
                        Boolean allStepsCompletedSuccessfully = deploymentJobsBySteps.keySet().size() == completedStepIds.size();
                        if (
                            destinationOrgStatus.toLowerCase() == IN_PROGRESS.toLowerCase() ||
                            destinationOrgStatus == PENDING ||
                            destinationOrgStatus == NOT_STARTED || 
                            (!failedStepIds.contains(deploymentJob.Step__c) && !completedStepIds.contains(deploymentJob.Step__c) && (destinationOrgStatus == COMPLETED_SUCCESSFULLY || destinationOrgStatus == COMPLETED_WITH_ERRORS)) ||
                            completedStepIds.contains(deploymentJob.Step__c) && !allStepsCompletedSuccessfully && destinationOrgStatus == COMPLETED_SUCCESSFULLY
                        ) {
                            newDeploymentStatus = IN_PROGRESS;
                            isAllcompleted = false;
                            break;
                        } else if (destinationOrgStatus == COMPLETED_SUCCESSFULLY && completedStepIds.contains(deploymentJob.Step__c) && allStepsCompletedSuccessfully) {
                            newDeploymentStatus = COMPLETED_SUCCESSFULLY;
                        } else if ((destinationOrgStatus == COMPLETED_WITH_ERRORS && newDeploymentStatus != CANCELLED && failedStepIds.contains(deploymentJob.Step__c)) ||
                            (destinationOrgStatus == COMPLETED_SUCCESSFULLY && newDeploymentStatus != CANCELLED && failedStepIds.contains(deploymentJob.Step__c))
                        ) {
                            newDeploymentStatus = COMPLETED_WITH_ERRORS;
                            isAllcompleted = true;
                            break;
                        } else if (destinationOrgStatus == CANCELLED) {
                            newDeploymentStatus = CANCELLED;
                            isCancelled = true;
                        }
                    }
                }
                if (isAllcompleted) {
                    deployment.Status__c = newDeploymentStatus;
                    deploymentsByIds.put(deployment.Id, deployment);
                }

                deploymentStatusesByIds.put(deploymentId, newDeploymentStatus);
            }
        }

        if(!destinationOrgsByIds.isEmpty()) {
            Utilities.Secure_DML(destinationOrgsByIds.values(), Utilities.DML_Action.UPD, schema.Sobjecttype.Destination_Org__c);
        }
        if(!stepsByIds.isEmpty()) {
            Utilities.Secure_DML(stepsByIds.values(), Utilities.DML_Action.UPD, schema.Sobjecttype.Step__c);
        }
        if(!deploymentsByIds.isEmpty()) {
            Utilities.Secure_DML(deploymentsByIds.values(), Utilities.DML_Action.UPD, schema.Sobjecttype.Deployment__c);
        }
        
        updateResultAndDeploymentJobStatusFieldsRelatedToDeployment(deploymentsByIds);
        updateDeploymentJobToInvokeParentDeployments(deploymentsByIds);
        return deploymentStatusesByIds;
    }

    private static void updateResultAndDeploymentJobStatusFieldsRelatedToDeployment(Map<Id, Deployment__c> deploymentsByIds) {
        if (!deploymentsByIds.isEmpty()) {
            List<Result__c> results = [
                SELECT Id, Deployment__c, End_Time__c, Status__c, (SELECT Id, Step__c, Status__c, Last_Result__c FROM Deployment_Jobs__r)
                FROM Result__c
                WHERE Deployment__c IN :deploymentsByIds.keySet() AND Function__c = NULL
                WITH SECURITY_ENFORCED
            ];
            List<Deployment_Job__c> deploymentJobs = new List<Deployment_Job__c>();
            for (Result__c resultRecord : results) {
                String deploymentStatus = deploymentsByIds.get(resultRecord.Deployment__c).Status__c;
                String resultStatus = deploymentStatus == COMPLETED_SUCCESSFULLY
                    ? SUCCESS
                    : deploymentStatus == COMPLETED_WITH_ERRORS ? FAILED : IN_PROGRESS.toLowerCase();
                resultRecord.Status__c = resultStatus;
                resultRecord.End_Time__c = System.now();
                for (Deployment_Job__c deploymentJobRecord : resultRecord.Deployment_Jobs__r) {
                    deploymentJobRecord.Status__c = resultStatus;
                    deploymentJobs.add(deploymentJobRecord);
                }
            }

            Utilities.Secure_DML(results, Utilities.DML_Action.UPD, schema.Sobjecttype.Result__c);
            Utilities.Secure_DML(deploymentJobs, Utilities.DML_Action.UPD, schema.Sobjecttype.Deployment_Job__c);
        }
    }

    private static void updateDeploymentJobToInvokeParentDeployments(Map<Id, Deployment__c> deploymentsByIds) {
        if (!deploymentsByIds.isEmpty()) {
            Set<Id> parentDeploymentIds = new Set<Id>();
            for (Deployment__c deployment : [
                SELECT Id, Parent_Deployment__c
                FROM Deployment__c
                WHERE Id IN :deploymentsByIds.keySet() AND Status__c = 'Completed Successfully'
            ]) {
                parentDeploymentIds.add(deployment.Parent_Deployment__c);
            }

            List<Deployment_Job__c> deploymentJobs = [
                SELECT Id, Status__c
                FROM Deployment_Job__c
                WHERE Step__r.Deployment__c IN :parentDeploymentIds AND Step__r.Order__c = 1
            ];
            for (Deployment_Job__c deploymentJob : deploymentJobs) {
                deploymentJob.Status__c = 'In Progress';
            }
            Utilities.Secure_DML(deploymentJobs, Utilities.DML_Action.UPD, schema.Sobjecttype.Deployment_Job__c);
        }
    }

    public static Map<String, String> getDestinationOrgStatus(List<Deployment_Job__c> deploymentJobs) {
        Map<String, String> destinationOrgStatusByIds = new Map<String, String>();
        for (Deployment_Job__c deploymentJobRecord : deploymentJobs) {
            String newDestinationOrgStatus = '';
            if (deploymentJobRecord.Status__c == PENDING && deploymentJobRecord.Destination_Org__r.Status__c == NOT_STARTED) {
                newDestinationOrgStatus = NOT_STARTED;
            } else if (deploymentJobRecord.Status__c == PENDING || deploymentJobRecord.Status__c.toLowerCase() == IN_PROGRESS.toLowerCase()) {
                newDestinationOrgStatus = IN_PROGRESS;
            } else if (deploymentJobRecord.Status__c == SUCCESS) {
                newDestinationOrgStatus = COMPLETED_SUCCESSFULLY;
            } else if (deploymentJobRecord.Status__c == FAILED) {
                newDestinationOrgStatus = COMPLETED_WITH_ERRORS;
            } else if (deploymentJobRecord.Status__c == CANCELLED) {
                newDestinationOrgStatus = CANCELLED;
            }
            String key = deploymentJobRecord.Id + '_' + deploymentJobRecord.Destination_Org__c;
            destinationOrgStatusByIds.put(key, newDestinationOrgStatus);
        }
        return destinationOrgStatusByIds;
    }

    public class ManualTaskStepAttachmentDetails {
        public String m { get; set; }
        public String l { get; set; }
        public String t { get; set; }
    }
}