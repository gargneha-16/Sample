import { LightningElement, api, wire } from 'lwc';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

import { publish, MessageContext } from 'lightning/messageService';
import alertMessage from '@salesforce/messageChannel/CopadoAlert__c';

import { schema, constants } from './constants';
import { reduceErrors } from 'c/copadocoreUtils';
import { getRelatedListConfiguration, getColumnsConfiguration, getUpgradedColumnConfiguration, getRowsData } from 'c/datatableService';

export default class SprintWallUserStoriesContainer extends LightningElement {
    @api recordId;
    @api fieldset = schema.FIELD_SET_NAME;

    orderBy = constants.ORDER_BY;
    rows = [];
    columns = [];
    queryConfig;
    recordLimit = constants.NUMBER_OF_RECORDS_LIMIT;

    schema = schema;
    relatedListConfig;

    _recordsOffset = 0;
    _rowFetched = false;
    _colFetched = false;
    _relatedListInfoFetched = false;

    get hasRows() {
        return this._rowFetched && this._colFetched && this._relatedListInfoFetched ? true : false;
    }

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this._fetchRelatedListConfiguration();
    }

    // TEMPLATE

    handleRefreshData() {
        this._rowFetched = false;
        this._fetchDataRows();
        const notifyChangeIds = [{ recordId: this.recordId }];
        getRecordNotifyChange(notifyChangeIds);
    }

    // PRIVATE

    async _fetchRelatedListConfiguration() {
        try {
            const childObjectConfiguration = {
                apiName: schema.USER_STORY,
                relationshipField: schema.SPRINT_FIELD
            };
            const config = await getRelatedListConfiguration(this, this.recordId, childObjectConfiguration);
            if (config) {
                this.relatedListConfig = config;
                this.relatedListConfig.sobjectLabelPlural = constants.RELATED_LIST_NAME;
                this._relatedListInfoFetched = true;
                this._fetchColumnConfigurations();
            }
        } catch (error) {
            console.error(error);
            const errorMessage = reduceErrors(error);
            this._handleError(constants.RELATED_LIST_ERROR + ': ' + errorMessage);
        }
    }

    async _fetchColumnConfigurations() {
        try {
            const columnsConfiguration = {
                objectApiName: schema.USER_STORY,
                fieldSetName: this.fieldset,
                hideDefaultColumnsActions: constants.HIDE_DEFAULT_COLUMNS_ACTION,
                sortable: constants.SORTABLE,
                editable: constants.ENABLE_INLINE_EDITING,
                searchable: constants.SEARCHABLE,
                filterable: constants.FILTERABLE
            };
            const data = await getColumnsConfiguration(this, columnsConfiguration);
            if (data && data.length) {
                const columnConfigs = getUpgradedColumnConfiguration(data, constants.ROW_ACTIONS, false);
                this.columns = columnConfigs;
                this._setPicklistNonEditable();
                this._fetchDataRows();
            } else {
                this._handleError(String.format(constants.NO_COLUMN_CONFIG_ERROR, this.fieldset));
            }
        } catch (error) {
            console.error(error);
            const errorMessage = reduceErrors(error);
            this._handleError(constants.FETCH_COLUMN_CONFIG_ERROR + ': ' + errorMessage);
        }
    }

    _setPicklistNonEditable() {
        if (this.columns) {
            this.columns.forEach((column) => {
                const isFieldTypePicklist =
                    column.typeAttributes && column.typeAttributes.fieldType && column.typeAttributes.fieldType.toLowerCase() === constants.PICKLIST;

                if (isFieldTypePicklist && column.editable) {
                    column.editable = false;
                }
            });
            this._colFetched = true;
        }
    }

    async _fetchDataRows() {
        try {
            const queryConfig = {
                fieldSetName: this.fieldset,
                objectApiName: schema.USER_STORY,
                relationshipFieldApi: schema.SPRINT_FIELD,
                recordId: this.recordId,
                orderBy: this.orderBy,
                numberOfRecordsLimit: this.recordLimit,
                recordsOffset: this._recordsOffset
            };
            this.queryConfig = queryConfig;
            const data = await getRowsData(this, queryConfig);

            this.rows = [];
            if (data) {
                this.rows = data;
                
                console.log(JSON.stringify(this.rows[0]));
            }
            this._rowFetched = true;
        } catch (error) {
            console.error(error);
            const errorMessage = reduceErrors(error);
            this._handleError(constants.FETCH_DATA_ERROR + ': ' + errorMessage);
        }
    }

    _handleError(message) {
        this._publishFlexiPageAlert(this._prepareAlert(message, constants.ERROR_VARIANT, true));
        this.rows = [];
        this._colFetched = true;
        this._rowFetched = true;
    }

    _publishFlexiPageAlert(alert) {
        publish(this.messageContext, alertMessage, alert);
    }

    _prepareAlert(message, variant, isDismissible) {
        return { message: message, variant: variant, dismissible: isDismissible, communicationId: constants.SPRINT_WALL_ALERT_COMMUNICATION_ID };
    }
}