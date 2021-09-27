import { LightningElement, api, track, wire } from 'lwc';
import { subscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import { loadStyle } from 'lightning/platformResourceLoader';
import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';
import copadoAlertPlaceHolderResources from '@salesforce/resourceUrl/copadoAlertPlaceHolder';
import { assignUUID, compareByVariant } from './utils';

export default class CopadoAlertPlaceHolder extends LightningElement {
    @api communicationId;

    @track alerts = [];
    subscription = null;

    // Note: By using the MessageContext @wire adapter, unsubscribe will be called
    // implicitly during the component destruction lifecycle.
    @wire(MessageContext)
    messageContext;

    async connectedCallback() {
        await loadStyle(this, copadoAlertPlaceHolderResources + '/copadoAlertPlaceHolderHidden.css');

        this.subscribeToAlertsChannel();
    }

    subscribeToAlertsChannel() {
        this.subscription = subscribe(this.messageContext, COPADO_ALERT_CHANNEL, (alert) => this.handleAlert(alert), {
            scope: APPLICATION_SCOPE
        });
    }

    handleAlert(alert) {
        if (this.isSameCommunicationId(alert)) {
            this.alerts.push(assignUUID(alert));
            this.alerts.sort(compareByVariant);
        }

        this._manageVisibility();
    }

    handleCloseAlert(event) {
        const index = event.target.dataset.index;
        this.alerts.splice(index, 1);

        this._manageVisibility();
    }

    isSameCommunicationId(alert) {
        return this.communicationId === alert.communicationId;
    }

    // PRIVATE

    _manageVisibility() {
        if (this.alerts.length === 0) {
            loadStyle(this, copadoAlertPlaceHolderResources + '/copadoAlertPlaceHolderHidden.css');
        } else {
            loadStyle(this, copadoAlertPlaceHolderResources + '/copadoAlertPlaceHolderVisible.css');
        }
    }
 }