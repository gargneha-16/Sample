@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.CyclomaticComplexity')
global with sharing class RunJob implements Queueable, Database.AllowsCallouts {

	private static final String STEP_CALLBACK = 'StepCallback';

	private JobExecution__c job;
	private String transactionId;
	private List<JobStep__c> steps;

	// CONSTRUCTOR

	public RunJob(Id jobId) {
		this( new JobExecutionsSelector().byId(jobId));
	}


	public RunJob(JobExecution__c job) {
		this.job = job;
	}


	// GLOBAL

	@InvocableMethod(label='Execute Job')
	global static void execute(List<Request> requests) {
		for (Request request : requests) {
			new RunJob(request.jobId).execute(request.allSteps, request.transactionId);
		}
	}


	// PUBLIC

	public void execute() {
		Boolean allSteps = true;
		String transactionId = null;

		execute(allSteps, transactionId);
	}


	public void execute(Boolean allSteps, String transactionId) {
		if(job == null) {
			throw new ApplicationException(Label.InvalidExecutionId);
		}

		// Note: if the job is already in progress, no need to start next step execution
		if(job.Status__c != 'In Progress') {
			clearSteps(allSteps);
            job.ErrorMessage__c = null;
            job.Status__c = 'In Progress';

            update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject> { job }).getRecords();

            System.enqueueJob(this);
		}
	}


    public void execute(QueueableContext ctx) {
        executeNextStep();
    }


	public void executeNextStep() {
		JobStep__c next = nextStep();

		if (next == null) {
			finish('Successful');
		}
		else {
			try {
				next.Result__c = invoke(next);
				update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject> { next }).getRecords();
			}
			catch(CopadoFunctionException ex) {
				next.Result__c = ex.resultId;
				update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject> { next }).getRecords();

				job.ErrorMessage__c = ex.getMessage();
				finish('Error');
			}
			catch(Exception ex) {
				job.ErrorMessage__c = ex.getMessage();
				finish('Error');
			}
		}
	}


	public void finish(String status) {
		job.Status__c = status;

		try {
			runCallback(job, status);
		}
		catch (Exception ex) {
			job.Status__c = 'Error';
			job.ErrorMessage__c = ex.getMessage();
		}

		update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject> { job }).getRecords();
	}


	// PRIVATE

	private String volumeOptionWithTransactionId(JobExecution__c job) {
		String result = job.VolumeOptions__c;

		if(String.isNotBlank(transactionId) && String.isNotBlank(job.VolumeOptions__c)) {
			List<Parameter> parameters = (List<Parameter>) JSON.deserialize(job.VolumeOptions__c, List<Parameter>.class);

			for(Parameter parameter : parameters) {
				if(parameter.name == 'transactionId') {
					parameter.name = transactionId;
				}
			}

			result = JSON.serialize(parameters);
		}

		return result;
	}


	private void clearSteps(Boolean allSteps) {
		steps = new JobStepsSelector().byJob(job.Id);

		for (JobStep__c step : steps) {
			if (allSteps || step.Status__c == 'Failed') {
				step.Result__c = null;
				step.ResultDataJson__c = null;
			}
		}

		update Security.stripInaccessible(AccessType.UPDATABLE, steps).getRecords();
	}


	private List<Parameter> volumeOptions(JobStep__c step) {
		List<Parameter> result = new List<Parameter>();

        if(String.isNotBlank(job.VolumeOptions__c)) {
            result = (List<Parameter>) JSON.deserialize(job.VolumeOptions__c, List<Parameter>.class);
        }

		if(isLastFunction(step) && getValue(result, 'preserveVolumeAfterExecution') == 'false') {
			result.add(new Parameter('killVolume', 'true'));
		}

		return result;
	}


	private String getValue(List<Parameter> parameters, String key) {
		String result = null;

		for(Parameter parameter : parameters) {
			if(parameter.name == key) {
				result = parameter.value;
				break;
			}
		}

		return result;
	}


	private Boolean isLastFunction(JobStep__c step) {
		Boolean result = false;

		for(Integer i = steps.size() - 1; i >= 0; i--) {
			if(steps[i].Type__c == 'Function') {
				result = (steps[i].Id == step.Id);
				break;
			}
		}

		return result;
	}


	private JobStep__c nextStep() {
		steps = new JobStepsSelector().byJob(job.Id);

		for(JobStep__c step : steps) {
			if(step.Status__c == 'Pending') {
				return step;
			}
		}

		return null;
	}


	private void runCallback(JobExecution__c job, String status) {
		if( String.isNotBlank(job.Callback__c) ) {
			Type callback = Type.forName(ns(job), localClass(job));
			if(callback == null) {
				throw new ApplicationException('Invalid class: ' + job.Callback__c);
			}

			((JobExecutionCallback) callback.newInstance()).execute(job, status);
		}
	}


	private Id invoke(JobStep__c step) {
		Id result;

		if (step.Type__c == 'Function') {
			result = invokeFunction(step);
		}
		else if (step.Type__c == 'Flow') {
			result = invokeFlow(step);
		}
		else if (step.Type__c == 'Manual') {
			result = invokeManual(step);
		}

		return result;
	}


	private Id invokeFunction(JobStep__c step) {
		StepConfig config = config(step);

		return new Function(config.functionName)
					.stepId(step.Id)
					.showValidationErrors(true)
					.parameters(config.parameters)
					.resultCallback(STEP_CALLBACK)
					.options(volumeOptions(step))
					.execute();
	}


	private Id invokeFlow(JobStep__c step) {
		StepConfig config = config(step);

		return new Flow(step.Id, config.flowName)
					.parameters(config.parameters)
					.resultCallback(STEP_CALLBACK)
					.execute();
	}


	private Id invokeManual(JobStep__c step) {
		return createResult(step, 'In Progress');
	}


	private Id createResult(JobStep__c step, String status) {
		return createResult(step, status, null);
	}


	private Id createResult(JobStep__c step, String status, String errorMessage) {
        Result__c result = new Result__c();
        result.Status__c = status;
        result.JobStep__c = step.Id;
        result.Job_Type__c = step.Type__c;
        result.ParentId__c = job.ParentId__c;
        result.Start_Time__c = Datetime.now();
        result.Error_Message__c = errorMessage;
        result.ApexCallback__c = STEP_CALLBACK;

		result = (Result__c) Security.stripInaccessible(AccessType.CREATABLE, new List<SObject> { result }).getRecords().get(0);
		insert result;

		return result.Id;
	}


    private String ns(JobExecution__c job) {
        return job.Callback__c.contains('.') ? job.Callback__c.substringBefore('.') : '';
    }


    private String localClass(JobExecution__c job) {
        return job.Callback__c.contains('.') ? job.Callback__c.substringAfter('.') : job.Callback__c;
    }


	private StepConfig config(JobStep__c step) {
		return (StepConfig) JSON.deserialize(step.ConfigJson__c, StepConfig.class);
	}


	// INNER

	global class Request {
		@InvocableVariable
		global Id jobId;

		@InvocableVariable
		global Id transactionId;

		@InvocableVariable
		global Boolean allSteps = true;
	}


	@TestVisible
	private class StepConfig {
		@TestVisible
        private String flowName;

		@TestVisible
        private String functionName;

		@TestVisible
        private List<Parameter> parameters;
	}
}