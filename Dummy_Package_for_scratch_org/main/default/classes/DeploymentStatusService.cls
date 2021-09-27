public with sharing class DeploymentStatusService implements CLIInterface {
       
    // PUBLIC

    public CLIInterface getInstance() {
        return this;
    }

    public String run(CliProxy.CLIWrapper record) {
        DeploymentStatus result = new DeploymentStatus();
        Request request = (Request) JSON.deserialize(record.body, Request.class);

        String messageLabel = 'Automation is {0}, {1} of {2} steps completed';
        Integer stepsCompleted = 0;

        List<Deployment__c> deployments = new DeploymentsSelector().byIdWithSteps(new Set<Id> {request.deploymentId});

        if(deployments.isEmpty()) {
            throw new CliException('Invalid deployment id: ' + record.body);
        }

        result.status = deployments[0].Status__c;
        Map<Id, Result> resultsByStepId = resultsByStepId(deployments[0].Steps__r);

        for(Step__c step : deployments[0].Steps__r) {
            Result stepResult = resultsByStepId.containsKey(step.Id) ? resultsByStepId.get(step.Id) : null;
            Boolean isCompleted = step.Status__c == 'Completed Successfully' || step.Status__c == 'Completed with Errors';
            result.addStepStatus(new StepStatus(step.Name, step.Status__c, isCompleted, stepResult));
        }
        String message = String.format(messageLabel, new List<String> {result.status, String.valueOf(result.stepsCompleted), String.valueOf(deployments[0].Steps__r.size())});
        
        return toResponse(message, result);
    }


    // PRIVATE
    
    private Map<Id, Result> resultsByStepId(List<Step__c> steps) {
        Map<Id, Result> result = new Map<Id, Result>();

        Set<Id> stepIds = new Map<Id, Step__c>(steps).keySet();
        
        for(Deployment_Job__c job : [SELECT Id, Step__c, Last_Result__c, Last_Result__r.Error_Message__c FROM Deployment_Job__c WHERE Step__c IN :stepIds]) {
            result.put(job.Step__c, new Result(job.Last_Result__c, job.Last_Result__r.Error_Message__c));
        }

        return result;
    }

    private String toResponse(String message, DeploymentStatus deploymentStatus) {
        Response result = new Response(CliSfDataWrapper.StatusResult.OK.name(), message, deploymentStatus);
        
        return (JSON.serialize(result));
    }

    // INNER

    public class Result { 
        public Id id;
        public String message;

        public Result(Id id, String message) {
            this.id = id;
            this.message = message;
        }
    }

    @TestVisible
    public class Response extends CliSfDataWrapper {
        DeploymentStatus deploymentStatus;

        public Response(String stat, String msg, DeploymentStatus deploymentStatus) {
            status = stat;
            message = msg;
            this.deploymentStatus = deploymentStatus;
        }
    }

    public class DeploymentStatus { 
        public String status;
        public Integer stepsCompleted = 0;
        public List<StepStatus> stepStatuses = new List<StepStatus>();

        public void addStepStatus(StepStatus stepStatus) {
            stepStatuses.add(stepStatus);
            stepsCompleted += (stepStatus.isCompleted ? 1 : 0);
        }
    }

    public class StepStatus { 
        public String name;
        public String status;
        public Result stepResult;
        public Boolean isCompleted;

        public StepStatus(String name, String status, Boolean isCompleted, Result stepResult) {
            this.name = name;
            this.status = status;
            this.stepResult = stepResult;
            this.isCompleted = isCompleted;
        }
    }

    public class Request { 
        public String deploymentId;
    }
}