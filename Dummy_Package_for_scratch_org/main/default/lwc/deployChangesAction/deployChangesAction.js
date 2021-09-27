import { LightningElement, api, wire } from 'lwc';

import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import { reduceErrors } from 'c/copadocoreUtils';
import { CloseActionScreenEvent } from 'lightning/actions';
import { publish, MessageContext } from 'lightning/messageService';

import execute from '@salesforce/apex/RunDeployJobTemplateHandler.execute';
import executeOutstanding from '@salesforce/apex/RunDeployJobTemplateHandler.executeOutstanding';
import validate from '@salesforce/apex/RunDeployJobTemplateHandler.validate';
import promoteJobAlreadyExecuted from '@salesforce/apex/RunDeployJobTemplateHandler.promoteJobAlreadyExecuted';
import deploymentJobAlreadyExecuted from '@salesforce/apex/RunDeployJobTemplateHandler.deploymentJobAlreadyExecuted';

import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';

import Cancel from '@salesforce/label/c.Cancel';
import Deploy from '@salesforce/label/c.DEPLOY';
import Environment from '@salesforce/label/c.Environment';
import Unable_to from '@salesforce/label/c.Unable_to';
import Start_new_execution from '@salesforce/label/c.Start_new_execution';
import Execute_only_outstanding_steps from '@salesforce/label/c.Execute_only_outstanding_steps';
import Deploy_Changes_Body from '@salesforce/label/c.Deploy_Changes_Body';
import Deploy_changes_to_Environment from '@salesforce/label/c.Deploy_changes_to_Environment';
import Deploy_not_changed from '@salesforce/label/c.Deploy_not_changed';
import Merge_change_is_not_done from '@salesforce/label/c.Merge_change_is_not_done';
import Error_while_processing_the_Deploy_Changes from '@salesforce/label/c.Error_while_processing_the_Deploy_Changes';
import Please_add_at_least_one_user_story_to_your_promotion from '@salesforce/label/c.Please_add_at_least_one_user_story_to_your_promotion';

import DESTINATION_ENVIRONMENT from '@salesforce/schema/Promotion__c.Destination_Environment__r.Name';

const fields = [DESTINATION_ENVIRONMENT];

export default class DeployChangesAction extends LightningElement {
    @api recordId;

    optionSelected = '';
    communicationId = 'promotionRecordPageAlerts';
    modalCommunicationId = 'modalAlerts';
    promotionHasUserStories = false;
    promoteJobExecuted = false;
    deploymentJobExecuted = false;
    showSpinner;

    label = {
        Cancel,
        Deploy,
        Environment,
        Deploy_not_changed
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
        return Deploy_changes_to_Environment + ' ' + "'" + this.destinationEnvironment + "'" + ' ' + Environment;
    }

    get modalMessageBody() {
        const normalText = Deploy_changes_to_Environment + ' ' + "'" + this.destinationEnvironment + "'" + ' ' + Environment;
        return this.promotionHasUserStories && this.promoteJobExecuted ? normalText : Unable_to + ' ' + normalText;
    }

    get body() {
        return this.promoteJobExecuted
            ? Deploy_Changes_Body
            : this.promotionHasUserStories
            ? Merge_change_is_not_done
            : Please_add_at_least_one_user_story_to_your_promotion;
    }

    get visible() {
        return this.promotionHasUserStories && this.promoteJobExecuted;
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
                const recordId = this.recordId;
                await execute({ recordId });
            }
            getRecordNotifyChange([{ recordId }]);
        } catch (error) {
            this.messageAlert(Error_while_processing_the_Deploy_Changes + ' ' + reduceErrors(error), 'error', true, this.communicationId);
        }
    }

    async validatePromotion() {
        const recordId = this.recordId;
        const result = await validate({ recordId });

        if (result) {
            this.promotionHasUserStories = true;
            await this.jobExecutionsCheck();
        }

        if (this.visible === false) {
            this.messageAlert(this.modalMessageBody, 'error', true, this.modalCommunicationId);
        }

        this.showSpinner = false;
    }

    async jobExecutionsCheck() {
        const recordId = this.recordId;
        try {
            this.promoteJobExecuted = await promoteJobAlreadyExecuted({ recordId });

            if (this.promoteJobExecuted) {
                this.deploymentJobExecuted = await deploymentJobAlreadyExecuted({ recordId });
            }
        } catch (error) {
            this.messageAlert(reduceErrors(error), 'error', true, this.communicationId);
            this.handleCancel();
        }
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