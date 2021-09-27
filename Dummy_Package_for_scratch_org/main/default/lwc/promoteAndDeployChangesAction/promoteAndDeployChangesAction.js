import { LightningElement, api, wire } from 'lwc';
import { reduceErrors } from 'c/copadocoreUtils';

import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { publish, MessageContext } from 'lightning/messageService';

import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';

import execute from '@salesforce/apex/RunPromoteAndDeployJobTemplateHandler.execute';
import executeOutstanding from '@salesforce/apex/RunPromoteAndDeployJobTemplateHandler.executeOutstanding';
import deploymentJobAlreadyExecuted from '@salesforce/apex/RunPromoteAndDeployJobTemplateHandler.deploymentJobAlreadyExecuted';
import validate from '@salesforce/apex/RunPromoteAndDeployJobTemplateHandler.validate';

import Cancel from '@salesforce/label/c.Cancel';
import Environment from '@salesforce/label/c.Environment';
import Unable_to from '@salesforce/label/c.Unable_to';
import Merge_and_Deploy from '@salesforce/label/c.Merge_and_Deploy';
import Merge_Deploy_Body from '@salesforce/label/c.Merge_Deploy_Body';
import Merge_and_deploy_not_changed from '@salesforce/label/c.Merge_and_deploy_not_changed';
import Merge_and_deploy_changes_to_Environment from '@salesforce/label/c.Merge_and_deploy_changes_to_Environment';
import Error_while_processing_the_Merge_and_Deploy_Changes from '@salesforce/label/c.Error_while_processing_the_Merge_and_Deploy_Changes';
import Please_add_at_least_one_user_story_to_your_promotion from '@salesforce/label/c.Please_add_at_least_one_user_story_to_your_promotion';
import Start_new_execution from '@salesforce/label/c.Start_new_execution';
import Execute_only_outstanding_steps from '@salesforce/label/c.Execute_only_outstanding_steps';

import DESTINATION_ENVIRONMENT from '@salesforce/schema/Promotion__c.Destination_Environment__r.Name';

const fields = [DESTINATION_ENVIRONMENT];

export default class PromoteAndDeployChangesAction extends LightningElement {
    @api recordId;

    optionSelected = '';
    communicationId = 'promotionRecordPageAlerts';
    modalCommunicationId = 'modalAlerts';
    promotionHasUserStories = false;
    deploymentJobExecuted = false;
    showSpinner;

    label = {
        Cancel,
        Merge_and_Deploy,
        Merge_and_deploy_not_changed
    };

    @wire(getRecord, { recordId: '$recordId', fields })
    promotion;

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

    get destinationEnvironment() {
        return getFieldValue(this.promotion.data, DESTINATION_ENVIRONMENT);
    }

    get options() {
        return [
            { label: Start_new_execution, value: 'executeAll' },
            { label: Execute_only_outstanding_steps, value: 'outstanding' }
        ];
    }

    get header() {
        return Merge_and_deploy_changes_to_Environment + ' ' + "'" + this.destinationEnvironment + "'" + ' ' + Environment;
    }

    get modalMessageBody() {
        const normalText = Merge_and_deploy_changes_to_Environment + ' ' + "'" + this.destinationEnvironment + "'" + ' ' + Environment;
        return this.promotionHasUserStories ? normalText : Unable_to + ' ' + normalText;
    }

    get body() {
        return this.promotionHasUserStories ? Merge_Deploy_Body : Please_add_at_least_one_user_story_to_your_promotion;
    }

    getSelection(event) {
        this.optionSelected = event.detail.value;
    }

    async handleConfirm() {
        this.handleCancel();

        try {
            const recordId = this.recordId;

            if (this.deploymentJobExecuted) {
                const runAllSteps = this.optionSelected === '' || this.optionSelected === 'executeAll';
                await executeOutstanding({ recordId, runAllSteps });
            } else {
                await execute({ recordId });
            }
            getRecordNotifyChange([{ recordId }]);
        } catch (error) {
            this.messageAlert(Error_while_processing_the_Merge_and_Deploy_Changes + ' ' + reduceErrors(error), 'error', true, this.communicationId);
        }
    }

    async jobExecutionCheck() {
        const recordId = this.recordId;
        try {
            this.deploymentJobExecuted = await deploymentJobAlreadyExecuted({ recordId });
        } catch (error) {
            this.messageAlert(reduceErrors(error), 'error', true, this.communicationId);
            this.handleCancel();
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

    messageAlert(message, variant, dismissible, communicationId) {
        const payload = {
            variant,
            message,
            dismissible,
            communicationId
        };
        publish(this.messageContext, COPADO_ALERT_CHANNEL, payload);
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}