public with sharing class PackageImportAction implements Actionable, JobExecutionCallback {
    // public

    @InvocableMethod(label='Package Import Action' category='Copado Action')
    public static List<Response> startImport(List<Request> requests) {
        validateRequest(requests);
        Response response = import(requests[0]);

        return new List<Response>{ response };
    }

    @SuppressWarnings('PMD.EmptyStatementBlock')
    public void execute(JobExecution__c job, String status) {
        // EMPTY CALLBACK
        // For future use
    }

    // PRIVATE

    private static Response import(Request request) {
        String jobtemplate = getJobTemplateName(request);
        JobExecution__c job = startJobExecution(jobTemplate, request);

        return new Response(job);
    }

    private static void validateRequest(List<Request> requests) {
        if (requests.size() > 1) {
            throw new ApplicationException('Only 1 request is available.');
        }

        validateRepository(requests[0]);
    }

    private static String getJobTemplateName(Request request) {
        String platform = String.isNotBlank(request.pipelineId)
                            ? fromPipeline(request.pipelineId)
                            : request.platformName;

        if (String.isBlank(platform)) {
            throw new ApplicationException('Please provide valid pipeline or platform details.');
        }

        return defaultJobTemplate(platform);
    }

    private static JobExecution__c startJobExecution(String jobTemplate, Request importRequest) {
        CreateExecution.Request executionRequest = new CreateExecution.Request();

        executionRequest.templateName = jobTemplate;
        executionRequest.dataJson = JSON.serialize(importRequest);
        executionRequest.runAfterInstantiation = true;

        return new CreateExecution(executionRequest).execute();
    }

    private static String fromPipeline(String pipelineId) {
        List<Deployment_Flow__c> pipeline = new PipelineSelector().byId(new Set<Id>{ pipelineId });

        if (pipeline.isEmpty()) {
            throw new ApplicationException('Pipeline not found.');
        }

        return pipeline.get(0).Platform__c;
    }

    private static String defaultJobTemplate(String platform) {
        MultiCloudAutomation__mdt templates = new MultiCloudAutomationsSelector()
                                                    .byPlatform(new Set<String>{ platform })
                                                    ?.get(platform);

        if (templates == null) {
            throw new ApplicationException('Template not found.');
        }

        return templates.PackageImportAPIName__c;
    }

    private static void validateRepository(Request request) {
        List<Git_Repository__c> repository = [SELECT Id FROM Git_Repository__c WHERE Id = :request.repositoryId WITH SECURITY_ENFORCED LIMIT 1];

        if (repository.isEmpty()) {
            throw new ApplicationException('Repository not found.');
        }
    }

    // INNER

    public class Request {
        @InvocableVariable(required=true label='Package Name or Id')
        public String packageNameOrId;

        @InvocableVariable(required=true label='Repository Id')
        public String repositoryId;

        @InvocableVariable(label='Pipeline Id')
        public String pipelineId;

        @InvocableVariable(label='Platform Name')
        public String platformName;

        @InvocableVariable(label='Platform Arguments in JSON format')
        public String jsonInformation;
    }

    public class Response {
        @InvocableVariable
        public JobExecution__c job;

        public Response(JobExecution__c job) {
            this.job = job;
        }
    }
}