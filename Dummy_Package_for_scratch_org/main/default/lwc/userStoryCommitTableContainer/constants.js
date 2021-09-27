import ENABLED from '@salesforce/label/c.Enabled';
import DISABLED from '@salesforce/label/c.Disabled';
import PREVIOUS_SELECTIONS from '@salesforce/label/c.PreviousSelections';
import PREVIOUS_SELECTIONS_HELP_TEXT from '@salesforce/label/c.PreviousSelectionsHelpText';
import CHANGES from '@salesforce/label/c.Changes';
import SELECTED from '@salesforce/label/c.SELECTED';
import NAME from '@salesforce/label/c.NAME';
import TYPE from '@salesforce/label/c.TYPE';
import DIRECTORY from '@salesforce/label/c.Directory';
import LAST_MODIFIED_DATE from '@salesforce/label/c.Last_Modified_Date';
import LAST_MODIFIED_BY from '@salesforce/label/c.LASTMODIFIEDBY';
import OPERATION from '@salesforce/label/c.Operation';
import ADD from '@salesforce/label/c.ADD';
import DELETE from '@salesforce/label/c.DELETE';
import RETRIEVE_ONLY from '@salesforce/label/c.RETRIEVE_ONLY';

import METADATA_ACTION_FIELD from '@salesforce/schema/User_Story_Metadata__c.Action__c';
import METADATA_API_NAME_FIELD from '@salesforce/schema/User_Story_Metadata__c.Metadata_API_Name__c';
import METADATA_DIRECTORY_FIELD from '@salesforce/schema/User_Story_Metadata__c.ModuleDirectory__c';
import METADATA_TYPE_FIELD from '@salesforce/schema/User_Story_Metadata__c.Type__c';

export const label = {
    ENABLED,
    DISABLED,
    PREVIOUS_SELECTIONS,
    PREVIOUS_SELECTIONS_HELP_TEXT,
    CHANGES,
    SELECTED,
    NAME,
    TYPE,
    DIRECTORY,
    LAST_MODIFIED_DATE,
    LAST_MODIFIED_BY,
    OPERATION,
    ADD,
    DELETE,
    RETRIEVE_ONLY
};

export const schema = {
    METADATA_ACTION_FIELD,
    METADATA_API_NAME_FIELD,
    METADATA_DIRECTORY_FIELD,
    METADATA_TYPE_FIELD
};