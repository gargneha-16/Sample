public with sharing class PackageVersionCreateService implements CLIInterface {

    // PUBLIC

    public String run(CliProxy.CLIWrapper cliRequest) {
        try {
            PackageVersionCreateAction.Request request = asRequest(cliRequest.body);
            JobExecution__c job = new PackageVersionCreateAction(request).execute();

            return new Response(CliSfDataWrapper.StatusResult.OK.name(), 'Package Version creation started successfully.', job).serialize();
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    private PackageVersionCreateAction.Request asRequest(String requestBody) {
        return (PackageVersionCreateAction.Request) JSON.deserialize(requestBody, PackageVersionCreateAction.Request.class);
    }

    // INNER

    @TestVisible
    private class Response extends CliSfDataWrapper {
        @TestVisible
        private JobExecution__c job;

        public Response(String status, String message, JobExecution__c job) {
            this.job = job;
            this.status = status;
            this.message = message;
        }

        public String serialize() {
            return JSON.serialize(this, true);
        }
    }
}