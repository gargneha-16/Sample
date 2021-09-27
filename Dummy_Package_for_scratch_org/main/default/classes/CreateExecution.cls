@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class CreateExecution {
    private Request request;
    private Integer order = 1;

    // GLOBAL

	@InvocableMethod(label='Execute Job Template')
	global static List<JobExecution__c> execute(List<Request> requests) {
		List<JobExecution__c> result = new List<JobExecution__c>();

		for (Request request : requests) {
            result.add(new CreateExecution(request).execute());
		}

		return result;
	}


    // CONSTRUCTOR

    public CreateExecution(Request request) {
        assertRequest(request);
        this.request = request;
    }


    // PUBLIC

    public JobExecution__c execute() {
        JobExecution__c result = jobExecution();

        if(request.runAfterInstantiation) {
            new RunJob(result).execute();
        }

        return result;
    }


    // PRIVATE


    @SuppressWarnings('PMD.ApexCRUDViolation')
    private JobExecution__c jobExecution() {
        JobExecution__c result = new JobExecution__c();
        JobTemplate__c template = getTemplate();

        if(String.isNotBlank(request.parentId)) {
            setParentId(result, Id.valueOf(request.parentId));
        }

        result.Status__c = 'Not Started';
        result.Template__c = template.Id;
        result.Callback__c = request.callback;
        result.DataJson__c = request.dataJson;
        result.Pipeline__c = request.pipelineId;
        result.Source__c = String.isNotBlank(request.sourceId) ? Id.valueOf(request.sourceId) : null;
        result.Destination__c = String.isNotBlank(request.destinationId) ? Id.valueOf(request.destinationId) : null;
        result = (JobExecution__c) Security.stripInaccessible(AccessType.CREATABLE, new List<SObject> { result }).getRecords().get(0);
        insert result;

        result.VolumeOptions__c = JSON.serializePretty(volumeOptions(template, result.Id), true);
        update result;

        cloneSteps(result, template.JobSteps__r);

        return result;
    }


    private JobTemplate__c getTemplate() {
        List<JobTemplate__c> result = new JobTemplatesSelector().byName(request.templateName);

        if(result.isEmpty()) {
            throw new ApplicationException(Label.InvalidTemplateId);
        }

        return result[0];
    }


    private List<Parameter> volumeOptions(JobTemplate__c template, Id executionId) {
        List<Parameter> result = new List<Parameter>();

        if(String.isNotBlank(template.VolumeOptions__c)) {
            result = (List<Parameter>) JSON.deserialize(template.VolumeOptions__c, List<Parameter>.class);
        }

        result.add(transactionParameter(executionId));

        return result;
    }


    private Parameter transactionParameter(Id executionId) {
        String transactionId = (String.isNotBlank(request.transactionId)) ? request.transactionId : executionId;

        return new Parameter('transactionId', transactionId);
    }


    private void setParentId(JobExecution__c job, Id parentId) {
        String objectType = objectType(parentId);
        String parentField = parentFieldByType().containsKey(objectType) ? parentFieldByType().get(objectType) : 'ParentRecord_Id__c';

        job.put(parentField, parentId);
    }


    private void cloneSteps(JobExecution__c job, List<JobStep__c> steps) {
        List<JobStep__c> result = new List<JobStep__c>();

        if(request.preSteps != null) {
            result.addAll(asClonedStep(job, request.preSteps));
        }

        result.addAll(asClonedStep(job, steps));

        if(request.postSteps != null) {
            result.addAll(asClonedStep(job, request.postSteps));
        }

        insert Security.stripInaccessible(AccessType.CREATABLE, result).getRecords();
    }


    private List<JobStep__c> asClonedStep(JobExecution__c job, List<JobStep__c> steps) {
        List<JobStep__c> result = new List<JobStep__c>();

        for(JobStep__c step : steps) {
            result.add(asClonedStep(job, step));
        }

        return result;
    }

    private JobStep__c asClonedStep(JobExecution__c job, JobStep__c step) {
        JobStep__c result = step.clone();
        result.Order__c = order++;
        result.JobTemplate__c = null;
        result.UserStory__c = null;
        result.JobExecution__c = job.Id;

        return result;
    }


    private void assertRequest(Request request) {
        if(String.isBlank(request.templateName)) {
            throw new ApplicationException(Label.InvalidTemplateId);
        }
    }


    private String objectType(Id recordId) {
        return (String.isNotBlank(recordId) ? recordId.getSObjectType().getDescribe().getLocalName() : '');
    }


    private Map<String, String> parentFieldByType() {
        return new Map<String, String> {
            'Deployment__c' => 'Deployment__c',
            'Promotion__c' => 'Promotion__c',
            'User_Story_Commit__c' => 'UserStoryCommit__c',
            'Git_Backup__c' => 'Snapshot__c'
        };
    }


	// INNER

	global class Request {
		@InvocableVariable
		global String templateName;

		@InvocableVariable
		global String transactionId;

		@InvocableVariable
		global String parentId;
        
		@InvocableVariable
		global String pipelineId;

		@InvocableVariable
		global String sourceId;

		@InvocableVariable
		global String destinationId;

		@InvocableVariable
		global String callback;

		@InvocableVariable
		global String dataJson;

		@InvocableVariable
		global List<JobStep__c> preSteps;

		@InvocableVariable
		global List<JobStep__c> postSteps;

		@InvocableVariable
		global Boolean runAfterInstantiation = false;
	}
}