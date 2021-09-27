global with sharing class SourceMemberResult {
    global String CreatedDate;
    global LookupUserField CreatedBy;
    global String LastModifiedDate;
    global LookupUserField LastModifiedBy;
    global Boolean IsNameObsolete;
    global String MemberName;
    global String MemberType;

    global with sharing class LookupUserField {
        global String Name;
    }
}