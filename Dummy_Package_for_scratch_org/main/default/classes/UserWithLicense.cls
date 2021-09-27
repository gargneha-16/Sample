public with sharing class UserWithLicense {
    @AuraEnabled
    public User user;
    @AuraEnabled
    public Map<String, Boolean> packageLicenses;
    @AuraEnabled
    public Copado_License__c license;

    public UserWithLicense(User user, List<String> packageLicenses, Copado_License__c license) {
        this.user = user;
        this.license = license;

        this.packageLicenses = new Map<String, Boolean>{
            'copado' => false,
            'copadometrics' => false,
            'copadovsm' => false
        };

        if (packageLicenses != null) {
            for (String pkg : packageLicenses) {
                this.packageLicenses.put(pkg, true);
            }
        }
    }
}