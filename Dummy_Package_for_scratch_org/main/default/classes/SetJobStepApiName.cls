public inherited sharing class SetJobStepApiName {
    private List<JobStep__c> steps;

    // CONSTRUCTOR

    public SetJobStepApiName(List<JobStep__c> steps) {
        this.steps = steps;
    }


    // PUBLIC

    public void execute() {
        Set<Id> parentIds = parentIds(steps);
        Map<Id, JobExecution__c> executionsById = new Map<Id, JobExecution__c>( new JobExecutionsSelector().byId(parentIds) );
        Map<Id, JobTemplate__c> templatesById = new Map<Id, JobTemplate__c>( new JobTemplatesSelector().byId(parentIds) );

        for(JobStep__c step : steps) {
            String parentName = templatesById.containsKey(step.JobTemplate__c) ?
                                    (String) templatesById.get(step.JobTemplate__c).get('Name') :
                                (executionsById.containsKey(step.JobExecution__c) ?
                                    (String) executionsById.get(step.JobExecution__c).get('Name') : null);

            step.ApiName__c = parentName + '_' + step.Name;
        }
    }

    // PRIVATE

    private Set<Id> parentIds(List<JobStep__c> steps) {
        Set<Id> result = new Set<Id>();

        for (JobStep__c step : steps) {
            if(step.JobExecution__c != null) {
                result.add(step.JobExecution__c);
            }
            else if(step.JobTemplate__c != null) {
                result.add(step.JobTemplate__c);
            }
        }

        return result;
    }
}