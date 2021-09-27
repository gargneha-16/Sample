public with sharing class RestrictStandardStepModification {

    private List<JobStep__c> steps;

    // CONSTRUCTOR

    public RestrictStandardStepModification(List<JobStep__c> steps) {
        this.steps = steps;
    }


    // PUBLIC

    public void execute() {
        if(!isStandardEditAllowed()) {
            Map<Id, JobTemplate__c> templatesById = templatesById();

            for(JobStep__c step : steps) {
                if(isStandard(templatesById,step)) {
                    step.addError(Label.StandardTemplateModificationNotAllowed);
                }
            }
        }
    }


    // PRIVATE

    private Boolean isStandard(Map<Id, JobTemplate__c> templatesById, JobStep__c step) {
        return (
            templatesById.containsKey(step.JobTemplate__c) &&
            templatesById.get(step.JobTemplate__c).Type__c == 'Standard'
        );
    }


    private Map<Id, JobTemplate__c> templatesById() {
        Set<Id> templateIds = templateIds();

        return new Map<Id, JobTemplate__c>([SELECT Id, Name, Type__c FROM JobTemplate__c WHERE Id IN :templateIds]);
    }


    private Set<Id> templateIds() {
        Set<Id> result = new Set<Id>();

        for(JobStep__c step : steps) {
            if(step.JobTemplate__c != null) {
                result.add(step.JobTemplate__c);
            }
        }

        return result;
    }


    private Boolean isStandardEditAllowed() {
        Settings__c setting = Settings__c.getOrgDefaults();

        return Boolean.valueOf(setting.Enable_Standard_Job_Template_Edit__c);
    }
}