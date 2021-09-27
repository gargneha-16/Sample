public with sharing class PackageVersionCreateAction {

    private Request request;

    // CONSTRUCTOR

    public PackageVersionCreateAction(Request request) {
        this.request = request;
    }


    // public

    @InvocableMethod(label='Package Version Create Action' category='Copado Action')
    public static List<Response> create(List<Request> requests) {
        assertRequest(requests);
        Request request = requests[0];

        JobExecution__c job = new PackageVersionCreateAction(request).execute();

        return new List<Response>{ new Response(job) };
    }


    public JobExecution__c execute() {
        Artifact__c artifact = getArtifact();
        Artifact_Version__c version = createPackageVersion(artifact);

        return new CreateExecution(executionRequest(artifact, version)).execute();
    }


    // PRIVATE


    @SuppressWarnings('PMD.ApexCRUDViolation')
    private Artifact_Version__c createPackageVersion(Artifact__c artifact) {
        Artifact_Version__c result = new Artifact_Version__c();
        result.Artifact__c = artifact.Id;
        result.Version_Name__c = request.versionName;
        result.Version_number__c = request.versionNumber;
        result.Version_Description__c = request.description;
        result = (Artifact_Version__c) Security.stripInaccessible(AccessType.CREATABLE, new List<SObject> { result }).getRecords()[0];
        insert result;

        return result;
    }


    private static void assertRequest(List<Request> requests) {
        if (requests.size() != 1) {
            throw new ApplicationException(Label.MultiplePackageVersionCreationRequestNotAllowed);
        }
    }


    private Artifact__c getArtifact() {
        List<Artifact__c> result = [SELECT Pipeline__r.Platform__c, Target_Dev_Hub_Org__r.Environment__c FROM Artifact__c WHERE Id = :request.packageId WITH SECURITY_ENFORCED];

        if(result.isEmpty()) {
            throw new ApplicationException(Label.InvalidPackageId);
        }

        return result[0];
    }


    private CreateExecution.Request executionRequest(Artifact__c artifact, Artifact_Version__c version) {
        CreateExecution.Request result = new CreateExecution.Request();

        result.dataJson = request.json;
        result.parentId = version.Id;
        result.runAfterInstantiation = true;
        result.templateName = getJobTemplateName(artifact);
        result.destinationId = artifact.Target_Dev_Hub_Org__r?.Environment__c;

        return result;
    }


    private String getJobTemplateName(Artifact__c artifact) {
        String platform = artifact.Pipeline__r?.Platform__c;
        MultiCloudAutomation__mdt actionTemplate = new MultiCloudAutomationsSelector().byPlatform(platform);

        return actionTemplate?.PackageVersionCreateApiName__c;
    }


    // INNER

    public class Request {
        @InvocableVariable(required=true label='Package Id')
        public String packageId;

        @InvocableVariable(required=true label='Version Name')
        public String versionName;

        @InvocableVariable(required=true label='Version Number')
        public String versionNumber;

        @InvocableVariable(required=false label='Description')
        public String description;

        @InvocableVariable(label='Version data JSON format')
        public String json;

        public Request(String packageId, String json) {
            this.packageId = packageId;
            this.json = json;
        }
    }

    public class Response {
        @InvocableVariable
        public JobExecution__c job;

        public Response(JobExecution__c job) {
            this.job = job;
        }
    }
}