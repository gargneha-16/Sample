import { LightningElement, api, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { CurrentPageReference } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';

import { namespace } from 'c/copadocoreUtils';

import HIDE_LIGHTNING_HEADER from '@salesforce/resourceUrl/HideLightningHeader';

export default class CustomHighlightPanel extends LightningElement {

    @api iconName;
    @api title;

    recordName;
    sobjectType;
    formFields;
    recordId;

    @wire(CurrentPageReference)
    getParameters(pageReference) {
        if (pageReference && pageReference.state) {
            const parameterName = `${(namespace || 'c__')}recordId`;
            this.recordId = pageReference.state[parameterName];
        }
    }

    @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Compact'], modes: ['View'] })
    wiredRecord({ error, data }) {
        if (error) {
            console.error(error);
        } else if (data) {
            this.sobjectType = data.apiName;
            if (data.fields.Name) {
                this.recordName = data.fields.Name.value;
            }
            this.formFields = Object.keys(data.fields);
        }
    }

    connectedCallback() {
        loadStyle(this, HIDE_LIGHTNING_HEADER);
    }
}