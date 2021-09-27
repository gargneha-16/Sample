public with sharing class JobStepTrigger extends fflib_SObjectDomain {

    // CONSTRUCTOR

    public JobStepTrigger(List<JobStep__c> records) {
        super(records);
    }


    // PUBLIC

    public override void onApplyDefaults() {
        new SetJobStepApiName(records).execute();
    }


    public override void onValidate() {
        new RestrictStandardStepModification(records).execute();
    }


    public override void onValidate(Map<Id, SObject> oldMap) {
        new RestrictStandardStepModification(records).execute();
    }


    public override void onBeforeDelete() {
        new RestrictStandardStepModification(records).execute();
    }


    // INNER

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> records) {
            return new JobStepTrigger(records);
        }
    }
}