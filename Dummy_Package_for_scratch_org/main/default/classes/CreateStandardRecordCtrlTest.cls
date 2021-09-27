@IsTest
private class CreateStandardRecordCtrlTest {
	
    @IsTest
    private static void getSupportedObjectsByName() {
        // Setup
        SupportedObjectsSelector.mockRecords = new List<SupportedObject__mdt> { new SupportedObject__mdt() };

        // Exercise
        List<CreateStandardRecordCtrl.SupportedObject> result = CreateStandardRecordCtrl.getSupportedObjects();
			
        // Verify
        System.assertEquals(1, result.size());
    }
    
    @IsTest
    private static void allSupportedObject() {

        // Exercise
        List<SupportedObject__mdt> result = new SupportedObjectsSelector().allObjects();
			
        // Verify
        System.assertEquals(1, result.size());
    }
    
    @IsTest
    private static void getSupportedObjectsWithoutMock() {

        // Exercise
        Map<String, String> result = new SupportedObjectsSelector().all();
			
        // Verify
        System.assertEquals(1, result.size());
    }
    
    @IsTest
    private static void getRecordBundle() {
        // Setup
        Exception expectedException = null;
        
        Function__c f = new Function__c();
        f.API_Name__c = 'SampleFunction';
        f.Script__c = 'echo "Old"';
        insert f;
        
        // Exercise
        try {
            CreateStandardRecordCtrl.getRecordBundle(new List<Id> { f.Id });
        } catch(Exception ex) {
            expectedException = ex;
        }
        
        // Verify
        System.assertEquals(null, expectedException);
    }
}