import { LightningElement, api } from 'lwc';

// Import aura enabled apex methods
import validateOrgAndReturnResultWrapper from '@salesforce/apex/CredentialRecordPageHandler.validateOrgAndReturnResultWrapper';

export default class CredentialValidation extends LightningElement {
    @api recordId;

    resultWrapper = [];
    processCompleted = false;

    connectedCallback() {
        if (this.recordId) {
            this.validateOrg();
        }
    }
    validateOrg() {
        validateOrgAndReturnResultWrapper({ credentialId: this.recordId }).then(result => {
            if (result && result.length > 0) {
                this.resultWrapper = result;
                this.processCompleted = true;
            }
        });
    }
}