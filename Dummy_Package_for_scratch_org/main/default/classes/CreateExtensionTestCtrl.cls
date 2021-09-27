public with sharing class CreateExtensionTestCtrl {
    // PUBLIC

    @AuraEnabled(cacheable=true)
    public static TestTypesWrapper getTestTypesInfo() {
        TestTypesWrapper result = new TestTypesWrapper();

        List<ComboboxOption> categories = new List<ComboboxOption>();
        List<ComboboxOption> tools = new List<ComboboxOption>();

        try {
            List<TestType__mdt> testTypes = new TestTypesSelector().getAll();

            for (TestType__mdt testType : testTypes) {
                categories.add(new ComboboxOption(testType.Category__c));
                tools.add(new ComboboxOption(testType.Tool__c));
            }

            result.tools = tools;
            result.categories = categories;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    // PRIVATE

    @testVisible
    private class TestTypesWrapper {
        @AuraEnabled
        public List<ComboboxOption> categories;
        @AuraEnabled
        public List<ComboboxOption> tools;
    }

    @testVisible
    private class ComboboxOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;

        public ComboboxOption(String text) {
            this.label = text;
            this.value = text;
        }
    }
}