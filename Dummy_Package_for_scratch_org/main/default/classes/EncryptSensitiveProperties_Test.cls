@IsTest 
private class EncryptSensitiveProperties_Test {

    @IsTest
    private static void insertNonSenstitiveProperties() {

        // Exercise
        System_Property__c property = new System_Property__c();
        property.Is_Sensitive__c = false;
        property.Value__c = 'Sample Value';
        property.API_Name__c = 'InsensitivrProperty';

        property.User__c = UserInfo.getUserId();
        insert property;


        // Verify
        System.assertEquals('Sample Value', [SELECT Value__c FROM System_Property__c].Value__c);
    }
    

    @IsTest
    private static void insertSenstitiveProperties() {

        // Setup
        Test.setMock(WebServiceMock.class, new MdApiMock());
        
        // Exercise
        Test.startTest();
            System_Property__c property = new System_Property__c();
            property.Is_Sensitive__c = true;
            property.Value__c = 'Sample Value';
            property.API_Name__c = 'InsensitivrProperty';


        property.User__c = UserInfo.getUserId();
        insert property;
        Test.stopTest();



        // Verify
        System.assertEquals(null, [SELECT Value__c FROM System_Property__c].Value__c);
    }
   

    @IsTest
    private static void updateSenstitiveProperties() {

        // Setup
        Test.setMock(WebServiceMock.class, new MdApiMock());
        System_Property__c property = new System_Property__c();
        property.Is_Sensitive__c = true;
        property.Value__c = 'Sample Value';
        property.API_Name__c = 'InsensitivrProperty';


        property.User__c = UserInfo.getUserId();
        insert property;

        // Exercise
        Test.startTest();


        	property.Value__c = 'Updated Value';
        	update property;
		Test.stopTest();
        


        // Verify
        System.assertEquals(null, [SELECT Value__c FROM System_Property__c].Value__c);
    }
   

    @IsTest
    private static void updateNonSenstitivePropertiesToSensitive() {

        // Setup
        Test.setMock(WebServiceMock.class, new MdApiMock());
        System_Property__c property = new System_Property__c();
        property.Is_Sensitive__c = false;
        property.Value__c = 'Sample Value';
        property.API_Name__c = 'InsensitivrProperty';


        property.User__c = UserInfo.getUserId();
        insert property;

        // Exercise
        Test.startTest();


        	property.Is_Sensitive__c = true;
        	update property;
		Test.stopTest();
        


        // Verify
        System.assertEquals(null, [SELECT Value__c FROM System_Property__c].Value__c);
    }


    @IsTest
    private static void updateSenstitivePropertiesToNonSensitive() {

        // Setup
        Test.setMock(WebServiceMock.class, new MdApiMock());
        System_Property__c property = new System_Property__c();
        property.Is_Sensitive__c = true;
        property.Value__c = 'Sample Value';
        property.API_Name__c = 'InsensitivrProperty';


        property.User__c = UserInfo.getUserId();
        insert property;

        SensitivePropertySelector.mock(
            new List<SensitiveProperty__mdt>{
                new SensitiveProperty__mdt(DeveloperName = property.Id, Value__c = DeployAPI.encryptAPIKey('Sample Value'))
            }
        );



        // Exercise
        Test.startTest();
        	property.Is_Sensitive__c = false;
	        property.Value__c = null;
        	update property;
		Test.stopTest();
        


        // Verify
        System.assertEquals('Sample Value', [SELECT Value__c FROM System_Property__c].Value__c);
    }

    @IsTest
    private static void deleteSenstitiveProperties() {


        // Setup
        Test.setMock(WebServiceMock.class, new MdApiMock());
        System_Property__c property = new System_Property__c();
        property.Is_Sensitive__c = true;
        property.Value__c = 'Sample Value';
        property.API_Name__c = 'InsensitiveProperty';

        property.User__c = UserInfo.getUserId();

        insert property;
        
        SensitivePropertySelector.mock(new List<SensitiveProperty__mdt> {});
        


        // Exercise
        Test.startTest();
        	delete property;
		Test.stopTest();
        


        // Verify
        System.assertEquals(0, new SensitivePropertySelector().byName(new Set<Id> { property.Id}).size());
    }



    private class MdApiMock implements WebServiceMock {
        public void doInvoke(
            Object stub,
            Object request,
            Map<String, Object> response,
            String endpoint,
            String soapAction,
            String requestName,
            String responseNS,
            String responseName,
            String responseType
        ) {
            if (requestName == 'deleteMetadata') {
                response.put('response_x', deleteResponse());
            } else if (requestName == 'updateMetadata') {
                response.put('response_x', updateResponse());
            } else {


                response.put('response_x', createResponse());
            }
        }
        


        private MetadataService.createMetadataResponse_element createResponse() {
            MetadataService.createMetadataResponse_element responseElement = new MetadataService.createMetadataResponse_element();
            MetadataService.SaveResult sr = new MetadataService.SaveResult();
            sr.success = true;

            responseElement.result = new List<MetadataService.SaveResult>{ sr };
            
            return responseElement;
        }
        


        private MetadataService.updateMetadataResponse_element updateResponse() {
            MetadataService.updateMetadataResponse_element responseElement = new MetadataService.updateMetadataResponse_element();
            MetadataService.SaveResult sr = new MetadataService.SaveResult();
            sr.success = true;

            responseElement.result = new List<MetadataService.SaveResult>{ sr };
            
            return responseElement;
        }
        


        private MetadataService.deleteMetadataResponse_element deleteResponse() {
            MetadataService.deleteMetadataResponse_element responseElement = new MetadataService.deleteMetadataResponse_element();

            MetadataService.DeleteResult sr = new MetadataService.DeleteResult();
            sr.success = true;

            responseElement.result = new List<MetadataService.DeleteResult>{ sr };
            
            return responseElement;
        }
    }
}