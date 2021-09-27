public with sharing class RefreshRecentChanges {
    private String orgId;
    private DateTime dateTimeToRetrieveChanges;

    // CTOR

    public RefreshRecentChanges(String orgId) {
        this.orgId = orgId;
    }

    public RefreshRecentChanges(String orgId, DateTime dateTimeToRetrieveChanges) {
        this(orgId);
        this.dateTimeToRetrieveChanges = dateTimeToRetrieveChanges;
    }

    // PUBLIC

    public List<SourceMemberResult> execute() {
        SalesforceAPIProxyRequest payload = new SalesforceAPIProxyRequest(getEndpoint(), orgId).logLabelIdentifier('SourceMember Tooling API Query');

        SalesforceAPIProxyResponse response = (SalesforceAPIProxyResponse) new SalesforceAPIProxyCallout()
            .default()
            .body(payload)
            .request()
            .type(SalesforceAPIProxyResponse.class)
            .parseResponse();

        return processResponse(response);
    }

    // PRIVATE

    private String getEndpoint() {
        Attachment att;
        if (dateTimeToRetrieveChanges == null) {
            att = getOrgMetadataAttachment();
        }

        String toolingApiPath = '/services/data/v50.0/tooling';
        String queryPath = '/query/?q=';

        List<String> fields = new List<String>{
            'CreatedDate',
            'CreatedBy.Name',
            'LastModifiedDate',
            'LastModifiedBy.Name',
            'IsNameObsolete',
            'MemberName',
            'MemberType'
        };

        String validUrlDateTime = dateTimeToRetrieveChanges != null
            ? getValidUrlDatetime(dateTimeToRetrieveChanges)
            : getValidUrlDatetime(att.LastModifiedDate);

        String greaterEncoded = '%3E';

        String queryParamTemplate = 'SELECT+{0}+FROM+SourceMember+WHERE+LastModifiedDate{1}{2}{3}+LIMIT+1000';

        String queryParam = String.format(
            queryParamTemplate,
            new List<Object>{ String.join(fields, ','), greaterEncoded, validUrlDateTime, getOrgMetadataTypesFilter() }
        );

        return toolingApiPath + queryPath + queryParam;
    }

    private Attachment getOrgMetadataAttachment() {
        String query = new AttachmentsSelector()
            .newQueryFactory(false)
            .setEnforceFLS(true)
            .selectField('LastModifiedDate')
            .setCondition('ParentId = :orgId AND Name = \'MetaData\'')
            .setLimit(1)
            .toSOQL();

        return Database.query(query);
    }

    private String getValidUrlDatetime(Datetime dt) {
        return dt.formatGMT('yyyy-MM-dd HH:mm:ss').replace(' ', 'T') + 'Z';
    }

    private String getOrgMetadataTypesFilter() {
        String metadataTypes = new OrgsSelector().byId(new List<Id>{ orgId })[0].Metadata_Types__c;
        return String.isBlank(metadataTypes) ? '' : '+AND+MemberType+IN+(\'' + metadataTypes.replace(',', '\',\'') + '\')';
    }

    private List<SourceMemberResult> processResponse(SalesforceAPIProxyResponse response) {
        if (response.statusCode == 200) {
            SourceMemberQueryResult content = (SourceMemberQueryResult) JSON.deserialize(response.content, SourceMemberQueryResult.class);
            return content.records;
        } else {
            String message = String.isNotBlank(response.errorMessage())
                ? response.errorMessage()
                : Label.Refresh_Recent_Changes_Generic_Exception_Message;
            throw new ApplicationException(message);
        }
    }

    // INNER

    private with sharing class SourceMemberQueryResult {
        private List<SourceMemberResult> records;
    }
}