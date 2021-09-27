import { LightningElement, api, wire } from 'lwc';

import { getRecordUi } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';

import result from '@salesforce/apex/ResultMonitorLWCHandler.result';

export default class ResultMonitor extends NavigationMixin(LightningElement) {
    @api fieldApiName;
    @api recordId; // Necessary for lightning__FlowScreen
    @api objectApiName;

    _interval;
    _recordDetail;
    _showDetail = false;
    _hasPushTopic = false;

    @wire(getRecordUi, { recordId: '$recordId' })
    getStateParameters() {
        this.execute();
    }

    connectedCallback() {
        this.execute();
    }

    disconnectedCallback() {
        clearInterval(this._interval);
    }

    get stop() {
        const expectedStatus = new Set(['Success', 'Failed', 'Cancelled']);
        let isCompleted = false;
        if (this._recordDetail) {
            isCompleted = this._recordDetail.resultDetails.every(resultDetail => {
                return expectedStatus.has(resultDetail.resultStatus);
            });
        }

        return this._recordDetail?.resultDetails?.length !== 0 && isCompleted;
    }

    async getRecordDetails() {
        try {
            this._recordDetail = await result({
                recId: this.recordId,
                objectApiName: this.objectApiName,
                fieldApiName: this.fieldApiName
            });
            if (this._recordDetail.jobExecutionId) {
                this._showDetail = true;
            }
        } catch (error) {
            this.error = error;
        }
    }

    execute() {
        this.getRecordDetails();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._interval = setInterval(() => {
            this.getRecordDetails();
            if (this.stop) {
                clearInterval(this._interval);
            }
        }, 10000);
    }

    navigateToJobExecution() {
        if (this._recordDetail) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this._recordDetail.jobExecutionId,
                    objectApiName: this._recordDetail.jobExecutionObjectApiName,
                    actionName: 'view'
                }
            });
        }
    }
}