public inherited sharing class ValidatePlatformType {
    // TODO: remove this comment
    List<SObject> records;
    Map<Id, List<Deployment_Flow_Step__c>> connectionsByParentId;

    
    // CONSTRUCTOR

    public ValidatePlatformType(List<Environment__c> environments, Map<Id, Environment__c> oldRecords) {
        records = filter(environments, oldRecords);
        connectionsByParentId = new DeploymentFlowStepsSelector().byEnvironment(records);
    }


    public ValidatePlatformType(List<Deployment_Flow__c> piplines, Map<Id, Deployment_Flow__c> oldRecords) {
        records = filter(piplines, oldRecords);
        connectionsByParentId = new DeploymentFlowStepsSelector().byPipeline(records);
    }


    // PUBLIC

    public void execute() {
        for(SObject record : records) {
            if(connectionsByParentId.containsKey(record.Id)) {
                for(Deployment_Flow_Step__c connection : connectionsByParentId.get(record.Id)) {
                    if(platformTypeDifferent(connection)) {
                        record.addError(Label.InValidPlatformType);
                    }
                }
            }
        }
    }


    // PRIVATE

    private Boolean platformTypeDifferent(Deployment_Flow_Step__c connection) {
        return ((connection.Source_Environment__c != null && platformType(connection.Deployment_Flow__r.Platform__c) != platformType(connection.Source_Environment__r.Platform__c)) || 
                (connection.Destination_Environment__c != null && platformType(connection.Deployment_Flow__r.Platform__c) != platformType(connection.Destination_Environment__r.Platform__c)));
    }


    private List<SObject> filter(List<SObject> records, Map<Id, SObject> oldRecords) {
        List<SObject> result = new List<SObject>();

        if(records != null) {
            for(SObject record : records) {
                SObject oldRecord = oldRecords?.get(record.Id);
                
                if(isPlatformTypeChanged(record, oldRecord)) {
                    result.add(record);
                }
            }   
        }

        return result;
    }


    private Boolean isPlatformTypeChanged(SObject record, SObject oldRecord) {
        return (String.valueOf(record.get('Platform__c')) != String.valueOf(oldRecord?.get('Platform__c')));
    }


    private String platformType(String platformType) {
        return String.isBlank(platformType) ? 'Salesforce' : platformType;
    }
}