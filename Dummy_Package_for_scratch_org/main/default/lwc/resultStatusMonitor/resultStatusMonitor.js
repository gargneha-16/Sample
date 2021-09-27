import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

import STATUS from '@salesforce/schema/Result__c.Status__c';
import PROGRESS_STATUS from '@salesforce/schema/Result__c.Progress_Status__c';

import result from '@salesforce/apex/ResultMonitor.result';

import LATEST_UPDATES from '@salesforce/label/c.Latest_Updates';

export default class ResultStatusMonitor extends NavigationMixin(LightningElement) {
    label = {
        LATEST_UPDATES
    };

    @api recordId;
    @api headerText;
    @api headerTextRecordId;
    @api headerTextObjectApiName;
    @api enableHeaderAsLink;
    @api objectApiName;
    @api showDetailLink;
    @api contextId;
    @api contextName;
    @api contextObjectApiName;
    @api contextLabel;

    record;
    _interval;

    async getRecord() {
        try {
            this.record = await result({ id: this.recordId });
        } catch (error) {
            this.error = error;
        }
    }

    navigateToResult() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: this.objectApiName,
                actionName: 'view'
            }
        });
    }

    connectedCallback() {
        this.getRecord();

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._interval = setInterval(() => {
            this.getRecord();
            getRecordNotifyChange([{ recordId: this.recordId }]);

            if (!this.inProgress) {
                clearInterval(this._interval);
            }
        }, 5000);
    }

    disconnectedCallback() {
        clearInterval(this._interval);
    }

    toggleTooltip() {
        this.template.querySelectorAll('.slds-popover').forEach(tooltip => tooltip.classList.toggle('slds-hide'));
    }

    get message() {
        return this.record[PROGRESS_STATUS.fieldApiName] || this.status || 'Not Started';
    }

    get status() {
        return this.record[STATUS.fieldApiName];
    }

    get inProgress() {
        return this.status === 'In Progress';
    }

    get icon() {
        return {
            name: this.iconName,
            variant: this.iconVariant
        };
    }

    get iconName() {
        const iconByStatus = {
            Success: 'utility:success',
            Failed: 'utility:error',
            Cancelled: 'utility:close'
        };

        return iconByStatus[this.status] || 'utility:info';
    }

    get iconVariant() {
        const variantByStatus = {
            Success: 'success',
            Failed: 'error'
        };

        return variantByStatus[this.status];
    }
}