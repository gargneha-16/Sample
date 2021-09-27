import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import STATUS from '@salesforce/schema/Result__c.Status__c';
import PROGRESS_STATUS from '@salesforce/schema/Result__c.Progress_Status__c';

import result from '@salesforce/apex/ResultMonitor.result';

export default class ResultDetail extends NavigationMixin(LightningElement) {
    @api recordId;
    @api jobStepLabel;
    @api jobStepId;
    @api jobStepObjectApiName;
    @api resultId;
    @api resultObjectApiName;
    @api resultLabel;
    @api resultValue;

    record;
    _interval;

    async getRecordDetail() {
        try {
            if (this.recordId) {
                this.record = await result({ id: this.recordId });
            }
        } catch (error) {
            this.error = error;
        }
    }

    navigateToResult() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.resultId,
                objectApiName: this.resultObjectApiName,
                actionName: 'view'
            }
        });
    }

    navigateToJobStep() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.jobStepId,
                objectApiName: this.jobStepObjectApiName,
                actionName: 'view'
            }
        });
    }

    connectedCallback() {
        this.getRecordDetail();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._interval = setInterval(() => {
            this.getRecordDetail();

            if (!this.inProgress && !this.notStarted) {
                clearInterval(this._interval);
            }
        }, 5000);
    }

    disconnectedCallback() {
        clearInterval(this._interval);
    }

    get message() {
        return this.record ? this.record[PROGRESS_STATUS.fieldApiName] : 'Not Started' || this.status || 'Not Started';
    }

    get status() {
        return this.record ? this.record[STATUS.fieldApiName] : 'Not Started';
    }

    get inProgress() {
        return this.status === 'In Progress';
    }

    get notStarted() {
        return this.status === 'Not Started';
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
            Cancelled: 'utility:close',
            'Not Started': 'utility:clock'
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