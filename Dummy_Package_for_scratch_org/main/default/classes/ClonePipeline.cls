public with sharing class ClonePipeline {
    private static final Set<String> SYSTEM_FIELDS = new Set<String>{
        'isdeleted',
        'createddate',
        'lastmodifieddate',
        'createdbyid',
        'lastmodifiedbyid',
        'systemmodstamp',
        'lastvieweddate',
        'lastreferenceddate',
        'ownerid'
    };

    // PUBLIC

    @AuraEnabled(cacheable=false)
    public static String getData(Id recordId) {
        try {
            return new RecordData(recordId).asJsonString();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String saveCopy(String data) {
        try {
            return new CloneData((RecordData) JSON.deserialize(data, RecordData.class)).save();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // PRIVATE

    private abstract class Pipeline {
        protected String platform {
            get {
                return pipeline.Platform__c;
            }
        }
        protected Deployment_Flow__c pipeline;
        protected List<Deployment_Flow_Step__c> connections;
        protected List<Environment__c> environments;
        protected List<System_Property__c> properties;

        // PROTECTED

        protected void pipeline(Id id) {
            pipeline = Database.query(byId());
        }

        private void connections() {
            connections = Database.query(byPipeline());
        }

        protected void environments() {
            Set<Id> environmentIds = environmentIds();
            environments = Database.query(byIds());
        }

        protected abstract String byId();
        protected abstract String byPipeline();
        protected abstract String byIds();

        // PRIVATE

        private Set<Id> environmentIds() {
            Set<Id> result = new Set<Id>();

            for (Deployment_Flow_Step__c connection : connections) {
                result.add(connection.Source_Environment__c);
                result.add(connection.Destination_Environment__c);
            }

            return result;
        }
    }

    private class RecordData extends Pipeline {
        // CTOR

        public RecordData(Id id) {
            pipeline(id);
            connections();
            environments();
        }

        // PUBLIC

        public String asJsonString() {
            return JSON.serialize(this);
        }

        // PROTECTED

        protected override String byId() {
            return 'SELECT Name, Git_Repository__c, Main_Branch__c, Platform__c FROM Deployment_Flow__c WHERE Id = :id WITH SECURITY_ENFORCED';
        }

        protected override String byPipeline() {
            return 'SELECT Branch__c, Source_Environment__c, Destination_Environment__c FROM Deployment_Flow_Step__c WHERE Deployment_Flow__c = \'' +
                String.escapeSingleQuotes(pipeline.Id) +
                '\' WITH SECURITY_ENFORCED';
        }

        protected override String byIds() {
            return 'SELECT Name FROM Environment__c WHERE Id IN :environmentIds WITH SECURITY_ENFORCED';
        }
    }

    private class CloneData extends Pipeline {
        private RecordData record;

        // CTOR

        public CloneData(RecordData record) {
            record(record);
            pipeline(record.pipeline.Id);
            connections();
            environments();
            properties();
        }

        // PUBLIC

        public Id save() {
            pipeline(clonePipeline().Id);
            Map<Id, Environment__c> environmentClones = platform == 'Salesforce' ? new Map<Id, Environment__c>() : cloneEnvironments();
            cloneProperties(environmentClones);
            cloneConnections(environmentClones);

            return pipeline.Id;
        }

        // PROTECTED

        private void properties() {
            properties = Database.query(byParentIds());
        }

        protected override String byId() {
            return 'SELECT ' + pipelineFields() + ' FROM Deployment_Flow__c WHERE Id = :id WITH SECURITY_ENFORCED';
        }

        protected override String byPipeline() {
            return 'SELECT ' +
                connectionFields() +
                ' FROM Deployment_Flow_Step__c WHERE Deployment_Flow__c = \'' +
                String.escapeSingleQuotes(pipeline.Id) +
                '\' WITH SECURITY_ENFORCED';
        }

        protected override String byIds() {
            return 'SELECT ' + environmentFields() + ' FROM Environment__c WHERE Id IN :environmentIds WITH SECURITY_ENFORCED';
        }

        // PRIVATE

        private void record(RecordData record) {
            this.record = record;
        }

        private String byParentIds() {
            String query =
                'SELECT ' +
                propertyFields() +
                ' FROM System_Property__c WHERE Pipeline__c = \'' +
                String.escapeSingleQuotes(pipeline.Id) +
                '\'';

            if (platform != 'Salesforce') {
                query += ' OR Environment__c IN :environments';
            }
            query += ' WITH SECURITY_ENFORCED';

            return query;
        }

        private String pipelineFields() {
            return String.join(stripSystemFields(Deployment_Flow__c.sObjectType.getDescribe().fields.getMap().keySet()), ',');
        }

        private String connectionFields() {
            return String.join(stripSystemFields(Deployment_Flow_Step__c.sObjectType.getDescribe().fields.getMap().keySet()), ',');
        }

        private String environmentFields() {
            return String.join(stripSystemFields(Environment__c.sObjectType.getDescribe().fields.getMap().keySet()), ',');
        }

        private String propertyFields() {
            return String.join(stripSystemFields(System_Property__c.sObjectType.getDescribe().fields.getMap().keySet()), ',');
        }

        private List<String> stripSystemFields(Set<String> fields) {
            List<String> result = new List<String>();

            for (String field : fields) {
                if (!ClonePipeline.SYSTEM_FIELDS.contains(field)) {
                    result.add(field);
                }
            }

            return result;
        }

        private Deployment_Flow__c clonePipeline() {
            Deployment_Flow__c result = pipeline.clone();

            result.Name = record.pipeline.Name;
            result.Git_Repository__c = record.pipeline.Git_Repository__c;
            result.Main_Branch__c = record.pipeline.Main_Branch__c;
            result.Active__c = false;
            insert result;

            return result;
        }

        private Map<Id, Environment__c> cloneEnvironments() {
            List<Environment__c> records = clonedRecords();

            // StripInaccessible removes the clone source id from the cloned record, so Secure_DML is used instead.
            Utilities.Secure_DML(records, Utilities.DML_Action.INS, SObjectType.Environment__c);

            Map<Id, Environment__c> result = new Map<Id, Environment__c>();
            for (Environment__c clone : records) {
                result.put(clone.getCloneSourceId(), clone);
            }

            return result;
        }

        private List<Environment__c> clonedRecords() {
            List<Environment__c> result = new List<Environment__c>();
            Map<Id, Environment__c> environmentInputs = environmentInputs();

            for (Environment__c environment : environments) {
                Environment__c clone = environment.clone();
                clone.Name = environmentInputs.get(environment.Id)?.Name;
                clone.Org_ID__c = null;
                clone.Latest_Deployment__c = null;
                result.add(clone);
            }

            return result;
        }

        private Map<Id, Environment__c> environmentInputs() {
            Map<Id, Environment__c> result = new Map<Id, Environment__c>();

            if (record.environments != null) {
                for (Environment__c environment : record.environments) {
                    result.put(environment.Id, environment);
                }
            }

            return result;
        }

        private void cloneProperties(Map<Id, Environment__c> environmentClones) {
            List<System_Property__c> result = new List<System_Property__c>();

            for (System_Property__c property : properties) {
                System_Property__c clone = property.clone();
                clone.ParentId__c = null;
                clone.Value__c = null;
                if (String.isNotBlank(clone.Pipeline__c)) {
                    clone.Pipeline__c = pipeline.Id;
                } else if (String.isNotBlank(clone.Environment__c)) {
                    clone.Environment__c = environmentClones.get(property.Environment__c)?.Id;
                }
                result.add(clone);
            }

            insert Security.stripInaccessible(AccessType.CREATABLE, result).getRecords();
        }

        private Map<Id, Deployment_Flow_Step__c> connectionInputs() {
            Map<Id, Deployment_Flow_Step__c> result = new Map<Id, Deployment_Flow_Step__c>();

            if (record.connections != null) {
                result = new Map<Id, Deployment_Flow_Step__c>(record.connections);
            }

            return result;
        }

        private void cloneConnections(Map<Id, Environment__c> environmentClones) {
            List<Deployment_Flow_Step__c> result = new List<Deployment_Flow_Step__c>();

            Map<Id, Deployment_Flow_Step__c> inputs = connectionInputs();
            Map<String, String> branchesByOldName = branchesByOldName(inputs);

            for (Deployment_Flow_Step__c connection : connections) {
                String branch = inputs.get(connection.Id)?.Branch__c;
                String destinationBranch = branchesByOldName.get(connection.Destination_Branch__c);

                Deployment_Flow_Step__c clone = connection.clone();
                clone.Deployment_Flow__c = pipeline.Id;
                clone.Branch__c = branch;
                clone.Destination_Branch__c = String.isBlank(destinationBranch) ? pipeline.Main_Branch__c : destinationBranch;
                clone.Source_Environment__c = environmentClones.get(connection.Source_Environment__c)?.Id;
                clone.Destination_Environment__c = environmentClones.get(connection.Destination_Environment__c)?.Id;
                result.add(clone);
            }

            insert Security.stripInaccessible(AccessType.CREATABLE, result).getRecords();
        }

        private Map<String, String> branchesByOldName(Map<Id, Deployment_Flow_Step__c> inputs) {
            Map<String, String> result = new Map<String, String>();

            for (Deployment_Flow_Step__c connection : connections) {
                result.put(connection.Branch__c, inputs.get(connection.Id)?.Branch__c);
            }

            return result;
        }
    }
}