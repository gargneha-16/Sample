@SuppressWarnings('PMD')
public inherited sharing class StepExpression extends DynamicExpression {
    private static final String REGEX_FIRST_STEP_FIELD = '(?i)\\{\\$?(Job).(FirstStep).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_PREV_STEP_FIELD = '(?i)\\{\\$?(Job).(PrevStep).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_NEXT_STEP_FIELD = '(?i)\\{\\$?(Job).(NextStep).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_LAST_STEP_FIELD = '(?i)\\{\\$?(Job).(LastStep).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_NAMED_STEP_FIELD = '(?i)\\{\\$?(Job).(Step).([A-Za-z0-9-_ ]+).([A-Za-z0-9-_.]+)\\}';

    private static final String REGEX_FIRST_STEP_JSON = '(?i)\\{\\$?(Job).(FirstStep).(JSONResult).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_PREV_STEP_JSON = '(?i)\\{\\$?(Job).(PrevStep).(JSONResult).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_NEXT_STEP_JSON = '(?i)\\{\\$?(Job).(NextStep).(JSONResult).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_LAST_STEP_JSON = '(?i)\\{\\$?(Job).(LastStep).(JSONResult).([A-Za-z0-9-_.]+)\\}';
    private static final String REGEX_NAMED_STEP_JSON = '(?i)\\{\\$?(Job).(Step).([A-Za-z0-9-_ ]+).(JSONResult).([A-Za-z0-9-_.]+)\\}';

    private static final Pattern PATTERN_FIRST_STEP_FIELD = Pattern.compile(REGEX_FIRST_STEP_FIELD);
    private static final Pattern PATTERN_PREV_STEP_FIELD = Pattern.compile(REGEX_PREV_STEP_FIELD);
    private static final Pattern PATTERN_NEXT_STEP_FIELD = Pattern.compile(REGEX_NEXT_STEP_FIELD);
    private static final Pattern PATTERN_LAST_STEP_FIELD = Pattern.compile(REGEX_LAST_STEP_FIELD);
    private static final Pattern PATTERN_NAMED_STEP_FIELD = Pattern.compile(REGEX_NAMED_STEP_FIELD);

    private static final Pattern PATTERN_FIRST_STEP_JSON = Pattern.compile(REGEX_FIRST_STEP_JSON);
    private static final Pattern PATTERN_PREV_STEP_JSON = Pattern.compile(REGEX_PREV_STEP_JSON);
    private static final Pattern PATTERN_NEXT_STEP_JSON = Pattern.compile(REGEX_NEXT_STEP_JSON);
    private static final Pattern PATTERN_LAST_STEP_JSON = Pattern.compile(REGEX_LAST_STEP_JSON);
    private static final Pattern PATTERN_NAMED_STEP_JSON = Pattern.compile(REGEX_NAMED_STEP_JSON);

    String objectName;
    private Decimal currentOrder;
    private List<SObject> allSteps = new List<SObject>();

    // CONSTRUCTOR

    public StepExpression(String contextId) {
        this.contextId = contextId;
    }

    // PUBLIC

    public override Boolean matches(Parameter parameter) {
        return (PATTERN_FIRST_STEP_FIELD.matcher(parameter.value).matches() ||
            PATTERN_FIRST_STEP_JSON.matcher(parameter.value).matches() ||
            PATTERN_PREV_STEP_JSON.matcher(parameter.value).matches() ||
            PATTERN_PREV_STEP_FIELD.matcher(parameter.value).matches() ||
            PATTERN_NEXT_STEP_JSON.matcher(parameter.value).matches() ||
            PATTERN_NEXT_STEP_FIELD.matcher(parameter.value).matches() ||
            PATTERN_LAST_STEP_JSON.matcher(parameter.value).matches() ||
            PATTERN_LAST_STEP_FIELD.matcher(parameter.value).matches() ||
            PATTERN_NAMED_STEP_JSON.matcher(parameter.value).matches() ||
        PATTERN_NAMED_STEP_FIELD.matcher(parameter.value).matches());
    }

    public override void prepare() {
        objectName = objectName(recordId());
        List<String> fieldNames = fieldNames();

        if(!fieldNames.isEmpty() && objectName == 'Deployment_Job__c') {
            Deployment_Job__c currentJob = currentJob();
            currentOrder = currentJob.Step__r.Order__c;
            allSteps = allSteps(currentJob, fieldNames);
        } else if (!fieldNames.isEmpty() && objectName == 'JobStep__c') {
            JobStep__c currentStep = currentStep();
            currentOrder = currentStep.Order__c;
            allSteps = allSteps(currentStep, fieldNames);
        }
    }

    public override void parse(Parameter parameter) {
        Matcher prevStepField = PATTERN_PREV_STEP_FIELD.matcher(parameter.value);
        Matcher nextStepField = PATTERN_NEXT_STEP_FIELD.matcher(parameter.value);
        Matcher firstStepField = PATTERN_FIRST_STEP_FIELD.matcher(parameter.value);
        Matcher lastStepField = PATTERN_LAST_STEP_FIELD.matcher(parameter.value);
        Matcher namedStepField = PATTERN_NAMED_STEP_FIELD.matcher(parameter.value);

        Matcher prevStepJson = PATTERN_PREV_STEP_JSON.matcher(parameter.value);
        Matcher nextStepJson = PATTERN_NEXT_STEP_JSON.matcher(parameter.value);
        Matcher firstStepJson = PATTERN_FIRST_STEP_JSON.matcher(parameter.value);
        Matcher lastStepJson = PATTERN_LAST_STEP_JSON.matcher(parameter.value);
        Matcher namedStepJson = PATTERN_NAMED_STEP_JSON.matcher(parameter.value);

        if(firstStepJson.matches()) {
            SObject firstStep =  getStepByOrder(1);
            String propertyName = firstStepJson.group(4);
            String jsonResult = (objectName == 'Deployment_Job__c')
                ? String.valueOf(firstStep.get('JsonResult__c'))
                : String.valueOf(firstStep.get('ResultDataJson__c'));
            parameter.value = getValueFromJson(jsonResult, propertyName);
        } else if (prevStepJson.matches()) {
            SObject previousStep =  previousStep();
            String propertyName = prevStepJson.group(4);
            String jsonResult = (objectName == 'Deployment_Job__c')
                ? String.valueOf(previousStep.get('JsonResult__c'))
                : String.valueOf(previousStep.get('ResultDataJson__c'));

            parameter.value = getValueFromJson(jsonResult, propertyName);
        } else if (nextStepJson.matches()) {
            SObject nextStep =  nextStep();
            String propertyName = nextStepJson.group(4);
            String jsonResult = (objectName == 'Deployment_Job__c')
                ? String.valueOf(nextStep.get('JsonResult__c'))
                : String.valueOf(nextStep.get('ResultDataJson__c'));

            parameter.value = getValueFromJson(jsonResult, propertyName);
        } else if (lastStepJson.matches()) {
            SObject lastStep =  lastStep();
            String propertyName = lastStepJson.group(4);
            String jsonResult = (objectName == 'Deployment_Job__c')
                ? String.valueOf(lastStep.get('JsonResult__c'))
                : String.valueOf(lastStep.get('ResultDataJson__c'));

            parameter.value = getValueFromJson(jsonResult, propertyName);
        } else if (firstStepField.matches()) {
            SObject firstStep =  getStepByOrder(1);
            String propertyName = firstStepField.group(3);
            parameter.value = getValue(firstStep, propertyName);
        } else if (prevStepField.matches()) {
            SObject previousStep =  previousStep();
            String propertyName = prevStepField.group(3);
            parameter.value = getValue(previousStep, propertyName);
        } else if (nextStepField.matches()) {
            SObject nextStep =  nextStep();
            String propertyName = nextStepField.group(3);
            parameter.value = getValue(nextStep, propertyName);
        } else if (lastStepField.matches()) {
            SObject lastStep =  lastStep();
            String propertyName = lastStepField.group(3);
            parameter.value = getValue(lastStep, propertyName);
        } else if (namedStepJson.matches()) {
            String stepName = namedStepJson.group(3);
            String propertyName = namedStepJson.group(5);

            SObject step =  getStepByName(stepName);
            String jsonResult = (objectName == 'Deployment_Job__c')
                ? String.valueOf(step.get('JsonResult__c'))
                : String.valueOf(step.get('ResultDataJson__c'));

            parameter.value = getValueFromJson(jsonResult, propertyName);
        } else if (namedStepField.matches()) {
            String stepName = namedStepField.group(3);
            String propertyName = namedStepField.group(4);
            SObject step =  getStepByName(stepName);

            parameter.value = getValue(step, propertyName);
        }
    }

    // PRIVATE

    private Id recordId() {
        try {
            return Id.valueOf(contextId);
        } catch (Exception ex) {
            throw new CopadoFunctionException(
                String.format(Label.invalidContextId, new List<String>{ Label.DEPLOYMENT_JOB + ' / ' + Label.JobStep })
            );
        }
    }

    private JobStep__c currentStep() {
        return (JobStep__c) Database.query('SELECT JobExecution__c, Order__c FROM JobStep__c WHERE Id = :contextId WITH SECURITY_ENFORCED');
    }

    private List<SObject> allSteps(JobStep__c step, List<String> fieldNames) {
        Id executionId = step.JobExecution__c;

        return Database.query(
            'SELECT ' +
            String.join(fieldNames, ', ') +
            ' FROM JobStep__c WHERE JobExecution__c = :executionId WITH SECURITY_ENFORCED'
        );
    }

    private SObject previousStep() {
        Integer previousOrder = (currentOrder != null) ? Integer.valueOf(currentOrder) - 1 : null;

        return getStepByOrder(previousOrder);
    }

    private SObject nextStep() {
        Integer nextOrder = (currentOrder != null) ? Integer.valueOf(currentOrder) + 1 : null;

        return getStepByOrder(nextOrder);
    }

    private SObject lastStep() {
        return getStepByOrder(allSteps.size());
    }

    private SObject getStepByOrder(Integer order) {
        for(SObject step : allSteps) {
            if(Integer.valueOf(step.get('Order__c')) == order) {
                return step;
            }
        }

        throw new CopadoFunctionException(Label.Invalid_Step);
    }

    private SObject getStepByName(String stepName) {
        for(SObject step : allSteps) {
            if(String.valueOf(step.get('Name')) == stepName) {
                return step;
            }
        }

        throw new CopadoFunctionException(Label.Invalid_Step);
    }

    private List<SObject> allSteps(Deployment_Job__c currentJob, List<String> stepFields) {
        Id deploymentId = currentJob.Step__r.Deployment__c;
        String query =
            'SELECT Id, (SELECT ' +
            String.join(stepFields, ', ') +
            ' FROM Steps__r) FROM  Deployment__c WHERE Id = :deploymentId WITH SECURITY_ENFORCED';
        Deployment__c deployment = (Deployment__c) Database.query( String.escapeSingleQuotes(query) ).get(0);

        return deployment.Steps__r;
    }

    private Deployment_Job__c currentJob() {
        List<Deployment_Job__c> currentJobs = [
            SELECT Step__r.Order__c, Step__r.Deployment__c
                                                FROM Deployment_Job__c
            WHERE Id = :recordId()
            WITH SECURITY_ENFORCED
        ];
        if(currentJobs.isEmpty()) {
            throw new CopadoFunctionException(Label.InValidDeploymentJobId);
        }

        return currentJobs[0];
    }

    private List<String> fieldNames() {
        Set<String> result = new Set<String>();

        for(Parameter parameter : parameters) {
            Matcher prevStepField = PATTERN_PREV_STEP_FIELD.matcher(parameter.value);
            Matcher firstStepField = PATTERN_FIRST_STEP_FIELD.matcher(parameter.value);
            Matcher nextStepField = PATTERN_NEXT_STEP_FIELD.matcher(parameter.value);
            Matcher lastStepField = PATTERN_LAST_STEP_FIELD.matcher(parameter.value);
            Matcher namedStepField = PATTERN_NAMED_STEP_FIELD.matcher(parameter.value);

            Matcher prevStepJson = PATTERN_PREV_STEP_JSON.matcher(parameter.value);
            Matcher firstStepJson = PATTERN_FIRST_STEP_JSON.matcher(parameter.value);
            Matcher nextStepJson = PATTERN_NEXT_STEP_JSON.matcher(parameter.value);
            Matcher lastStepJson = PATTERN_LAST_STEP_JSON.matcher(parameter.value);
            Matcher namedStepJson = PATTERN_NAMED_STEP_JSON.matcher(parameter.value);

            String fieldName;

            if(prevStepJson.matches() || firstStepJson.matches() || nextStepJson.matches() || lastStepJson.matches() || namedStepJson.matches()) {
                fieldName = (objectName == 'Deployment_Job__c') ? 'JsonResult__c' : 'ResultDataJson__c';
            } else if (firstStepField.matches()) {
                fieldName = firstStepField.group(3);
            } else if (prevStepField.matches()) {
                fieldName = prevStepField.group(3);
            } else if (nextStepField.matches()) {
                fieldName = nextStepField.group(3);
            } else if (lastStepField.matches()) {
                fieldName = lastStepField.group(3);
            } else if (namedStepField.matches()) {
                fieldName = namedStepField.group(4);
            }

            result.add(fieldName);
        }

        if(!result.isEmpty()) {
            result.add('Name');
            result.add('Order__c');
        }

        return new List<String>(result);
    }
}