/* eslint-disable guard-for-in */
import { LightningElement, api, wire } from 'lwc';

import { reduceErrors } from 'c/copadocoreUtils';
import { publish, MessageContext } from 'lightning/messageService';

import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';

import fetchColumnsConfig from '@salesforce/apex/DynamicDatatableCtrl.fetchColumnsConfig';
import availableUserStories from '@salesforce/apex/PromotedUserStoriesDatatableController.availableUserStories';

import Fetch_Columns_Config_Error from '@salesforce/label/c.Fetch_Columns_Config_Error';
import Fetch_Data_Error from '@salesforce/label/c.Fetch_Data_Error';
import Save from '@salesforce/label/c.Save';
import Cancel from '@salesforce/label/c.Cancel';
import Add_User_Stories from '@salesforce/label/c.ManageUserStories';

const relatedListHeaderHeight = 125;

export default class PromotedUserStoriesAddUserStoriesModal extends LightningElement {
    @api promotionId;
    tableInfo;
    showSpinner;

    communicationId = 'promotionRecordPageAlerts';

    removeSaveButtonDisabled = true;

    label = {
        Save,
        Cancel,
        Add_User_Stories
    };

    _sobject = 'User_Story__c';
    _fieldset = 'Promotion_Related_List_Datatable';
    _columns;
    _allRows;
    _searchTerm;
    _height = window.innerHeight;
    _nonFreeHeight;

    @wire(MessageContext)
    messageContext;

    get height() {
        return `${this._height - this._nonFreeHeight}px`;
    }

    async connectedCallback() {
        this.resetTable();
    }

    renderedCallback() {
        window.addEventListener('resize', () => {
            this._height = window.innerHeight;
        });

        const countersFinishAt = this.template.querySelector('lightning-layout[data-id*="counters"]')?.getBoundingClientRect()?.bottom || 0;
        this._nonFreeHeight = countersFinishAt + relatedListHeaderHeight;
    }

    @api show() {
        this.template.querySelector('c-copadocore-modal').show();
    }

    @api hide() {
        this.template.querySelector('c-copadocore-modal').hide();
    }

    handleRowSelection(event) {
        this.removeSaveButtonDisabled = event.detail.selectedRows.length === 0;
    }

    handleCancel() {
        this.hide();
    }

    handleSave() {
        const userStoryIds = this.template.querySelector('c-related-list').tableComponent.selectedRows;
        const addUserStoriesEvent = new CustomEvent('adduserstories', {
            detail: {
                userStoryIds
            }
        });
        this.dispatchEvent(addUserStoriesEvent);
    }

    async _getRowsData() {
        let rows;
        try {
            rows = await availableUserStories({ promotionId: this.promotionId, selectFieldSet: this._fieldset });
        } catch (error) {
            this.messageAlert(Fetch_Data_Error + ' ' + reduceErrors(error), 'error', true);
        }
        return rows;
    }

    async _getColumnsConfig() {
        let columns;
        try {
            const columnsConfiguration = {
                objectApiName: this._sobject,
                fieldSetName: this._fieldset,
                editable: false,
                hideDefaultColumnsActions: true,
                searchable: true,
                sortable: true
            };

            columns = await fetchColumnsConfig({ columnsConfiguration });
        } catch (error) {
            this.messageAlert(Fetch_Columns_Config_Error + ' ' + reduceErrors(error), 'error', true);
        }
        return columns;
    }

    async _setTableInformation() {
        const [columns, rows] = await Promise.all([this._getColumnsConfig(), this._getRowsData()]);
        if (!(columns && rows)) {
            return;
        }
        const rowsCopy = [];
        for (const row of rows) {
            rowsCopy.push(Object.assign(row));
        }
        this.tableInfo = Object.assign(this.tableInfo || {}, { columns: columns }, { rows: rowsCopy });
    }

    async resetTable() {
        this.showSpinner = true;
        await this._setTableInformation();
        this.showSpinner = false;
    }

    messageAlert(message, variant, dismissible) {
        const payload = {
            variant,
            message,
            dismissible,
            communicationId: this.communicationId
        };
        publish(this.messageContext, COPADO_ALERT_CHANNEL, payload);
    }
}