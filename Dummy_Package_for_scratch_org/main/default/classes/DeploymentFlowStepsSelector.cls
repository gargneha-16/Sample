public inherited sharing class DeploymentFlowStepsSelector extends fflib_SObjectSelector {
    public Schema.SObjectType getSObjectType() {
        return Deployment_Flow_Step__c.SObjectType;
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Deployment_Flow_Step__c.Id,
            Deployment_Flow_Step__c.Branch__c,
            Deployment_Flow_Step__c.Source_Environment__c,
            Deployment_Flow_Step__c.Destination_Environment__c,
            Deployment_Flow_Step__c.Deployment_Flow__c,
            Deployment_Flow_Step__c.Last_Merge_Base__c,
            Deployment_Flow_Step__c.Last_Merge_CBM_Sync__c,
            Deployment_Flow_Step__c.Last_Pull_CBM_Sync__c,
            Deployment_Flow_Step__c.Destination_Branch__c
        };
    }

    public List<Deployment_Flow_Step__c> byParentIds(Id pipelineId, Id sourceEnvironmentId, Id targetEnvironmentId) {
        return (List<Deployment_Flow_Step__c>) Database.query(
            newQueryFactory()
                .setCondition(
                    Deployment_Flow_Step__c.Deployment_Flow__c +
                    ' = :pipelineId AND ' +
                    Deployment_Flow_Step__c.Source_Environment__c +
                    ' = :sourceEnvironmentId AND ' +
                    Deployment_Flow_Step__c.Destination_Environment__c +
                    ' = :targetEnvironmentId'
                )
                .toSOQL()
        );
    }

    public List<Deployment_Flow_Step__c> byPipelineAndSourceEnvironment(Id pipelineId, Id sourceEnvironmentId) {
        return (List<Deployment_Flow_Step__c>) Database.query(
            newQueryFactory()
                .setCondition(
                    Deployment_Flow_Step__c.Deployment_Flow__c +
                    ' = :pipelineId AND ' +
                    Deployment_Flow_Step__c.Source_Environment__c +
                    ' = :sourceEnvironmentId'
                )
                .toSOQL()
        );
    }

    public Map<Id, List<Deployment_Flow_Step__c>> byEnvironment(List<Environment__c> environments) {
        Map<Id, List<Deployment_Flow_Step__c>> result = new Map<Id, List<Deployment_Flow_Step__c>>();

        List<Deployment_Flow_Step__c> connections = (List<Deployment_Flow_Step__c>) Database.query(
            selectFields()
                .setCondition(
                    Deployment_Flow_Step__c.Source_Environment__c +
                    ' IN :environments OR ' +
                    Deployment_Flow_Step__c.Destination_Environment__c +
                    ' IN :environments'
                )
                .toSOQL()
        );

        for (Deployment_Flow_Step__c connection : connections) {
            if (!result.containsKey(connection.Source_Environment__c)) {
                result.put(connection.Source_Environment__c, new List<Deployment_Flow_Step__c>());
            }

            if (!result.containsKey(connection.Destination_Environment__c)) {
                result.put(connection.Destination_Environment__c, new List<Deployment_Flow_Step__c>());
            }

            result.get(connection.Source_Environment__c).add(connection);
            result.get(connection.Destination_Environment__c).add(connection);
        }

        return result;
    }

    public List<Deployment_Flow_Step__c> byEnvironment(Id environmentId) {
        return Database.query(
            selectFields()
                .setEnforceFLS(true)
                .setCondition(
                    Deployment_Flow_Step__c.Source_Environment__c +
                    ' = :environmentId OR ' +
                    Deployment_Flow_Step__c.Destination_Environment__c +
                    ' = :environmentId'
                )
                .toSOQL()
        );
    }

    public Map<Id, List<Deployment_Flow_Step__c>> byPipeline(List<Deployment_Flow__c> pipelines) {
        Map<Id, List<Deployment_Flow_Step__c>> result = new Map<Id, List<Deployment_Flow_Step__c>>();
        Set<Id> pipelineIds = new Set<Id>();
        for (Deployment_Flow__c pipeline : pipelines) {
            pipelineIds.add(pipeline.Id);
        }
        result = new DeploymentFlowStepsSelector().byPipeline(pipelineIds);

        return result;
    }

    public Map<Id, List<Deployment_Flow_Step__c>> byPipeline(Set<Id> pipelineIds) {
        Map<Id, List<Deployment_Flow_Step__c>> result = new Map<Id, List<Deployment_Flow_Step__c>>();

        List<Deployment_Flow_Step__c> connections = (List<Deployment_Flow_Step__c>) Database.query(
            selectFields().setCondition(Deployment_Flow_Step__c.Deployment_Flow__c + ' IN :pipelineIds').toSOQL()
        );

        for (Deployment_Flow_Step__c connection : connections) {
            if (!result.containsKey(connection.Deployment_Flow__c)) {
                result.put(connection.Deployment_Flow__c, new List<Deployment_Flow_Step__c>());
            }
            result.get(connection.Deployment_Flow__c).add(connection);
        }

        return result;
    }

    // PRIVATE

    private fflib_QueryFactory selectFields() {
        return newQueryFactory()
            .selectField('Source_Environment__r.Name')
            .selectField('Destination_Environment__r.Name')
            .selectField('Deployment_Flow__r.Platform__c')
            .selectField('Source_Environment__r.Platform__c')
            .selectField('Destination_Environment__r.Platform__c')
            .selectField('Deployment_Flow__r.Static_Code_Analysis_Settings__c')
            .selectField('Deployment_Flow__r.Static_Code_Analysis_Settings__r.RecordTypeId')
            .selectField('Deployment_Flow__r.Git_Repository__c');
    }
}