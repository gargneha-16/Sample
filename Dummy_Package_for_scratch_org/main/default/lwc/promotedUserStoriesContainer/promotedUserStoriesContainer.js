/* eslint-disable guard-for-in */
import { LightningElement, api, wire } from 'lwc';

import { reduceErrors } from 'c/copadocoreUtils';
import { publish, MessageContext } from 'lightning/messageService';

import fetchColumnsConfig from '@salesforce/apex/DynamicDatatableCtrl.fetchColumnsConfig';
import fetchData from '@salesforce/apex/PromotedUserStoriesDatatableController.fetchData';
import addSelectedUserStoriesToPromotion from '@salesforce/apex/PromotedUserStoriesDatatableController.addSelectedUserStoriesToPromotion';

import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';

import Fetch_Columns_Config_Error from '@salesforce/label/c.Fetch_Columns_Config_Error';
import Fetch_Data_Error from '@salesforce/label/c.Fetch_Data_Error';
import Add_User_Stories from '@salesforce/label/c.ManageUserStories';
import Promoted_User_Stories from '@salesforce/label/c.Promoted_User_Stories';
import Remove_User_Stories from '@salesforce/label/c.Remove_User_Stories';
import User_stories_added_successfully from '@salesforce/label/c.User_stories_added_successfully';

const relatedListHeaderHeight = 125;

export default class PromotedUserStoriesContainer extends LightningElement {
    @api recordId;
    tableInfo;
    showSpinner;

    communicationId = 'promotionRecordPageAlerts';

    label = {
        Add_User_Stories,
        Promoted_User_Stories,
        Remove_User_Stories
    };

    removeSelectedDisabled = true;

    _sobject = 'Promoted_User_Story__c';
    _fieldset = 'Promoted_User_Story_Datatable';
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
        this.showSpinner = true;
        this.resetTable();
    }

    renderedCallback() {
        window.addEventListener('resize', () => {
            this._height = window.innerHeight;
        });

        const countersFinishAt = this.template.querySelector('lightning-layout[data-id*="counters"]')?.getBoundingClientRect()?.bottom || 0;
        this._nonFreeHeight = countersFinishAt + relatedListHeaderHeight;
    }

    async _addUserStories(userStoryIds) {
        let rows;
        try {
            rows = await addSelectedUserStoriesToPromotion({ promotionId: this.recordId, userStoryIds });
        } catch (error) {
            this.messageAlert(Fetch_Data_Error + ' ' + reduceErrors(error), 'error', true);
        }
        return rows;
    }

    async _getRowsData() {
        let rows;
        try {
            rows = await fetchData({ promotionId: this.recordId, selectFieldSet: this._fieldset });
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

    handleRemovePromotedUserStories() {
        const promotedUserStoryIds = this.template.querySelector('c-related-list').tableComponent.selectedRows;
        const removeSelectedPopup = this.template.querySelector('c-promoted-user-stories-removal-modal');
        removeSelectedPopup.promotedUserStoryIds = promotedUserStoryIds;

        removeSelectedPopup.show();
    }

    handleAddPromotedUserStories() {
        const addUsersStoriesPopup = this.template.querySelector('c-promoted-user-stories-add-user-stories-modal');
        addUsersStoriesPopup.show();
    }

    handleRowSelection(event) {
        this.removeSelectedDisabled = event.detail.selectedRows.length === 0;
    }

    async resetTable() {
        await this._setTableInformation();
        this.showSpinner = false;
    }

    async handleRefresh() {
        this.showSpinner = true;
        this.tableInfo = undefined;
        this.resetTable();
    }

    async handleAddUserStories(event) {
        this.showSpinner = true;
        const addUsersStoriesPopup = this.template.querySelector('c-promoted-user-stories-add-user-stories-modal');
        addUsersStoriesPopup.hide();

        const userStoryIds = event.detail.userStoryIds;

        const results = await Promise.all([this._addUserStories(userStoryIds)]);

        if (results[0] !== undefined) {
            this.tableInfo = undefined;
            this.resetTable();
            this.messageAlert(User_stories_added_successfully, 'success', true);
        }
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