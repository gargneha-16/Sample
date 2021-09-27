public with sharing class CustomLookupComponentHelper {
    // PUBLIC

    @AuraEnabled(cacheable=true)
    public static List<LookupSearchResult> search(CustomLookupQueryConfiguration queryConfig, String objectLabel) {
        try {
            List<SObject> searchResults = Database.query(queryConfig.getFormattedQuery());
            List<LookupSearchResult> result = new List<LookupSearchResult>();

            String icon = 'standard:choice';
            for (SObject obj : searchResults) {
                String name = String.valueOf(obj.get('Name'));
                String subtitle = objectLabel + ' • ' + name;
                result.add(new LookupSearchResult(obj.Id, objectLabel, icon, name, subtitle));
            }

            return result;
        } catch (Exception e) {
            throw new ApplicationException().auraHandled(e);
        }
    }
}