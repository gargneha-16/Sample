public with sharing class PackageImportService implements CLIInterface {
    // PUBLIC

    public String run(CliProxy.CLIWrapper request) {
        try {
            PackageImportAction.Request importRequest = (PackageImportAction.Request) JSON.deserialize(
                request.body,
                PackageImportAction.Request.class
            );

            List<PackageImportAction.Response> response = PackageImportAction.startImport(new List<PackageImportAction.Request>{ importRequest });

            return new Response(CliSfDataWrapper.StatusResult.OK.name(), 'Package import started successfully.', response[0]).serialize();
        } catch (Exception ex) {
            throw new ApplicationException(ex.getMessage());
        }
    }

    // INNER

    @TestVisible
    private class Response extends CliSfDataWrapper {
        @TestVisible
        private PackageImportAction.Response body;

        public Response(String status, String message, PackageImportAction.Response body) {
            this.status = status;
            this.message = message;
            this.body = body;
        }

        public String serialize() {
            return JSON.serialize(this, true);
        }
    }
}