public with sharing class OnJobStepComplete {

    public static final String STEP_ENDPOINT = '/events/copado/v1/step-result/';
    private List<Event__e> records;

    // CONSTRUCTOR

    public OnJobStepComplete(List<Event__e> records) {
        this.records = records;
    }


    // PUBLIC

    public void execute() {

        for(Event__e event : filterRelevant( records )) {
            Id resultId = Id.valueOf(event.Topic_Uri__c.substringAfter(STEP_ENDPOINT));
            EventPayload payload = asEventPayload(event.Payload__c);

            Result__c result = updateStatus(resultId, payload);

            new StepCallback().execute(result.JobStep__r.JobExecution__c, payload.status());
        }
    }


    // PRIVATE

    private Result__c updateStatus(Id resultId, EventPayload payload) {
        Result__c result = [SELECT Id, JobStep__c, JobStep__r.JobExecution__c, Result_Data__c, Error_Message__c FROM Result__c WHERE Id = :resultId WITH SECURITY_ENFORCED];
        result.Status__c = payload.status();
        result.Result_Data__c = payload.data;
        result.Error_Message__c = payload.errorMessage;
        update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject> { result }).getRecords();

        JobStep__c step = new JobStep__c();
        step.Id = result.JobStep__c;
        step.ResultDataJson__c = payload.data;
        update Security.stripInaccessible(AccessType.UPDATABLE, new List<SObject> { step }).getRecords();

        return result;
    }


    private EventPayload asEventPayload(String payload) {
        EventPayload result;

        try {
            result = (EventPayload) JSON.deserialize(payload, EventPayload.class);
        }
        catch (Exception ex) {
            result = new EventPayload(false, Label.invalidStepPayload);
        }

        return result;
    }


    private List<Event__e> filterRelevant(List<Event__e> arbitraryEvents) {
        List<Event__e> result = new List<Event__e>();

        for(Event__e event : arbitraryEvents) {
            if(isRelevant(event)) {
                result.add(event);
            }
        }

        return result;
    }


    private Boolean isRelevant(Event__e event) {
        return (event.Topic_Uri__c != null &&
                 event.Topic_Uri__c.startsWith(STEP_ENDPOINT) &&
                 isResult(event));
    }


    private Boolean isResult(Event__e event) {
        String recordId = event.Topic_Uri__c.substringAfter(STEP_ENDPOINT);

        return (objectType(recordId) == 'Result__c');
    }


    private String objectType(Id recordId) {
        return (String.isNotBlank(recordId) ? recordId.getSObjectType().getDescribe().getLocalName() : '');
    }


    // INNER

    public class EventPayload {

        public String data;
        public String errorMessage;
        public Boolean isSuccess = false;


        public EventPayload(Boolean isSuccess, String errorMessage) {
            this.isSuccess = isSuccess;
            this.errorMessage = errorMessage;
        }


        public EventPayload(Boolean isSuccess, String errorMessage, String data) {
            this.data = data;
            this.isSuccess = isSuccess;
            this.errorMessage = errorMessage;
        }

        public String status() {
            return (isSuccess) ? 'Success' : 'Failed';
        }
    }
}