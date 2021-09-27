import { LightningElement, api } from 'lwc';

// Utils
import { flushPromises } from 'c/copadocoreUtils';

export default class CopadocoreErrorPopover extends LightningElement {
    @api title = 'Resolve error';
    @api message = '';

    displayPopover;

    constructor() {
        super();
        this.openPopOver();
    }

    @api
    async openPopOver() {
        if (!this.displayPopover) {
            this.displayPopover = true;
            await flushPromises();
        }

        const errorButtonElement = this.template.querySelector('button[id*="error-button"]');
        const popOverElement = this.template.querySelector('section[id*="popover-section"]');
        if (popOverElement) {
            popOverElement.style.display = 'inline';
            popOverElement.style.bottom = `${errorButtonElement.getBoundingClientRect().height + 10}px`;
            popOverElement.style.left = `-${errorButtonElement.getBoundingClientRect().width / 2}px`;
        }
    }

    closePopOver() {
        this.displayPopover = false;
    }

    async togglePopOver() {
        this.displayPopover = !this.displayPopover;

        await flushPromises();

        if (this.displayPopover) {
            this.openPopOver();
        }
    }
}