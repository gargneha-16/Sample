import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import { refreshApex } from '@salesforce/apex';
import { publish, MessageContext } from 'lightning/messageService';
import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';
import getTests from '@salesforce/apex/DefinitionOfDoneCtrl.getTests';
import deleteTest from '@salesforce/apex/DefinitionOfDoneCtrl.deleteTest';
import { label, schema } from './constants';

export default class DefinitionOfDone extends NavigationMixin(LightningElement) {
    @api recordId;

    @track tests = [];

    label = label;
    schema = schema;

    _wiredResults = [];

    @wire(MessageContext)
    messageContext;

    @wire(getTests, { recordId: '$recordId' })
    wiredTests(result) {
        this._wiredResults = result;
        if (result.data) {
            this.tests = result.data;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._interval = setInterval(async () => {
                await refreshApex(this._wiredResults);
            }, 5000);
        } else if (result.error) {
            let err = result.error;
            const errorAlert = {
                message: err.message || err.body.message,
                variant: 'error',
                dismissible: true,
                communicationId: 'userStoryAlerts'
            };
            publish(this.messageContext, COPADO_ALERT_CHANNEL, errorAlert);
        }
    }

    //PUBLIC

    navigateToNewTestRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: schema.TEST.objectApiName,
                actionName: 'new'
            }
        });
    }

    handleRowAction(event) {
        const actionName = event.detail.value;
        const testId = event.target.dataset.id;

        switch (actionName) {
            case label.Edit:
                this._handleEditRow(testId);
                break;
            case label.Delete:
                this._handleDeleteRow(testId);
                break;
            default:
        }
    }

    //PRIVATE

    _handleEditRow(id) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: id,
                objectApiName: schema.TEST.objectApiName,
                actionName: 'edit'
            }
        });
    }

    async _handleDeleteRow(id) {
        await deleteTest({ recordId: id });
        await refreshApex(this.tests);
    }
}