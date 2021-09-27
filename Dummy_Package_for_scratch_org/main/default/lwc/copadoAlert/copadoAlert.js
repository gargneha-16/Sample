import { LightningElement, api } from 'lwc';
import { getTheme, getIconName } from './utils';

export default class CopadoAlert extends LightningElement {
    @api message;
    @api variant;
    @api dismissible = false;

    get styleClasses() {
        return `slds-notify slds-notify_alert ${getTheme(this.variant)}`;
    }

    get iconName() {
        return getIconName(this.variant);
    }

    handleCloseAlert() {
        this.dispatchEvent(new CustomEvent('closealert'));
    }
}