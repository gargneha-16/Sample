@IsTest
private class StandardRecordStatusCtrlTest {

    @IsTest
    private static void getInsertedBundle() {

        // Setup
        Function__c f = new Function__c();
        f.API_Name__c = 'SampleFunction';
        f.Script__c = 'echo "Hello"';
        insert f;
        String bundleJson = CreateStandardRecords.serialize(new Set<Id> { f.Id });
        SObjectDataLoader.RecordsBundle bundle = (SObjectDataLoader.RecordsBundle) JSON.deserialize(bundleJson, SObjectDataLoader.RecordsBundle.class);
        
        String recordSetJson = JSON.serialize(bundle.RecordSetBundles[0]);

        StaticResourcesSelector.mock = new List<StaticResource> {
            new StaticResource(Name = 'CopadoStandardRecords', Body = Blob.valueOf(bundleJson))
        };

        SupportedObjectsSelector.mock = new Map<String, String> { 
            'copado__Function__c' => 'copado__API_Name__c'
         };


        // Exercise
        StandardRecordStatusCtrl.InsertedBundle result = StandardRecordStatusCtrl.getInsertedBundle(recordSetJson);
        

        // Verify
        System.assertNotEquals(null, result);
    }
    

    @IsTest
    private static void updateRecords() {

        // Setup
        Exception expectedException = null;
        System.Savepoint savePoint = Database.setSavepoint();
        Function__c f = new Function__c();
        f.API_Name__c = 'SampleFunction';
        f.Script__c = 'echo "Hello"';
        insert f;
        String json = CreateStandardRecords.serialize(new Set<Id> { f.Id });
        
        StaticResourcesSelector.mock = new List<StaticResource> {
            new StaticResource(Name = 'CopadoStandardRecords', Body = Blob.valueOf(json))
        };

        SupportedObjectsSelector.mock = new Map<String, String> { 
            'copado__Function__c' => 'copado__API_Name__c'
         };

        Database.rollback(savePoint);


        // Exercise
        try {
            StandardRecordStatusCtrl.updateRecords(null);
        } catch (Exception ex) {
            expectedException = ex;   
        }
        

        // Verify
        System.assertEquals(null, expectedException);

        List<Function__c> results = [SELECT Id, API_Name__c, Script__c FROM Function__c];
        System.assertEquals(1, results.size());
        System.assertEquals(f.API_Name__c, results[0].API_Name__c);
        System.assertEquals(f.Script__c, results[0].Script__c);
    }
    
}