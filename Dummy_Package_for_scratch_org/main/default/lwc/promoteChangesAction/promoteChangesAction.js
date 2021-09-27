import { LightningElement, api, wire } from 'lwc';
import { reduceErrors } from 'c/copadocoreUtils';

import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { publish, MessageContext } from 'lightning/messageService';

import execute from '@salesforce/apex/RunPromoteJobTemplateHandler.execute';
import executeOutstanding from '@salesforce/apex/RunPromoteJobTemplateHandler.executeOutstanding';
import jobAlreadyExecuted from '@salesforce/apex/RunPromoteJobTemplateHandler.jobAlreadyExecuted';
import validate from '@salesforce/apex/RunPromoteJobTemplateHandler.validate';

import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';

import Cancel from '@salesforce/label/c.Cancel';
import Merge from '@salesforce/label/c.Merge';
import Merge_changes from '@salesforce/label/c.Merge_changes';
import Merge_Changes_Body from '@salesforce/label/c.Merge_Changes_Body';
import Error_while_processing_the_Merge_Changes from '@salesforce/label/c.Error_while_processing_the_Merge_Changes';
import Please_add_at_least_one_user_story_to_your_promotion from '@salesforce/label/c.Please_add_at_least_one_user_story_to_your_promotion';
import Unable_to from '@salesforce/label/c.Unable_to';
import Merge_not_changed from '@salesforce/label/c.Merge_not_changed';
import Start_new_execution from '@salesforce/label/c.Start_new_execution';
import Execute_only_outstanding_steps from '@salesforce/label/c.Execute_only_outstanding_steps';

export default class PromoteChangesAction extends LightningElement {
    @api recordId;

    optionSelected = '';
    communicationId = 'promotionRecordPageAlerts';
    modalCommunicationId = 'modalAlerts';
    promotionHasUserStories = false;
    jobExecuted = false;
    showSpinner;

    label = {
        Cancel,
        Merge,
        Merge_changes,
        Merge_not_changed
    };

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
        }
    }

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.showSpinner = true;
        this.validatePromotion();
    }

    get options() {
        return [
            { label: Start_new_execution, value: 'executeAll' },
            { label: Execute_only_outstanding_steps, value: 'outstanding' }
        ];
    }

    get modalMessageBody() {
        return this.promotionHasUserStories ? Merge_changes : Unable_to + ' ' + Merge_changes;
    }

    get body() {
        return this.promotionHasUserStories ? Merge_Changes_Body : Please_add_at_least_one_user_story_to_your_promotion;
    }

    messageAlert(message, variant, dismissible, communicationId) {
        const payload = {
            variant,
            message,
            dismissible,
            communicationId
        };
        publish(this.messageContext, COPADO_ALERT_CHANNEL, payload);
    }

    getSelection(event) {
        this.optionSelected = event.detail.value;
    }

    async handleConfirm() {
        this.handleCancel();

        try {
            const recordId = this.recordId;

            if (this.jobExecuted) {
                const runAllSteps = this.optionSelected === '' || this.optionSelected === 'executeAll';
                await executeOutstanding({ recordId, runAllSteps });
            } else {
                await execute({ recordId });
            }
            getRecordNotifyChange([{ recordId }]);
        } catch (error) {
            this.messageAlert(Error_while_processing_the_Merge_Changes + ' ' + reduceErrors(error), 'error', true, this.communicationId);
        }
    }

    async validatePromotion() {
        const recordId = this.recordId;
        const result = await validate({ recordId });

        if (result) {
            this.promotionHasUserStories = true;
            await this.jobExecutionCheck();
        }

        if (this.promotionHasUserStories === false) {
            this.messageAlert(this.modalMessageBody, 'error', true, this.modalCommunicationId);
        }

        this.showSpinner = false;
    }

    async jobExecutionCheck() {
        const recordId = this.recordId;

        try {
            this.jobExecuted = await jobAlreadyExecuted({ recordId });
        } catch (error) {
            this.messageAlert(reduceErrors(error), 'error', true, this.communicationId);
            this.handleCancel();
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}