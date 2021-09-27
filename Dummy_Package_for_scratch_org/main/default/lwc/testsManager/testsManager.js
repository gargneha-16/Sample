import { LightningElement, api, wire, track } from 'lwc';

import { publish, MessageContext } from 'lightning/messageService';

import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';
import runTestsOf from '@salesforce/apex/TestsManagerCtrl.runTestsOf';
import getTests from '@salesforce/apex/TestsManagerCtrl.getTests';
import { label, schema } from './constants';
export default class TestsManager extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track filteredData = [];
    @track data = [];
    isLoading = false;
    columns = this._getColumns();
    searchValue = '';
    label = label;
    schema = schema;

    @wire(MessageContext)
    messageContext;

    // PUBLIC

    async connectedCallback() {
        try {
            this.isLoading = true;
            await this._refreshData();
        } catch (err) {
            const errorAlert = {
                message: err.message || err.body.message,
                variant: 'error',
                dismissible: true,
                communicationId: this._getCommunicationId()
            };
            publish(this.messageContext, COPADO_ALERT_CHANNEL, errorAlert);
        }
        this.isLoading = false;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._interval = setInterval(async () => {
            await this._refreshData();
        }, 5000);
    }

    async handleRun() {
        try {
            this.isLoading = true;

            this._resetData();
            await runTestsOf({ parentId: this.recordId });
            await this._refreshData();
        } catch (err) {
            const errorAlert = {
                message: err.message || err.body.message,
                variant: 'error',
                dismissible: true,
                communicationId: this._getCommunicationId()
            };
            publish(this.messageContext, COPADO_ALERT_CHANNEL, errorAlert);
        }

        this.isLoading = false;
    }

    onSearchFilter(event) {
        this.searchValue = event.target.value;
        this.filteredData = this._searchTextInData(this.data, this.searchValue);
    }

    // PRIVATE

    _resetData() {
        this.filteredData = [];
        this.data = [];
    }

    async _refreshData() {
        await this._refreshAllData();
        this._refreshFilteredData();
    }

    async _refreshAllData() {
        let filteredData = await getTests({ parentId: this.recordId });
        this.data = filteredData;
    }

    async _refreshFilteredData() {
        this.filteredData = this._searchTextInData(this.data, this.searchValue);
    }

    _getCommunicationId() {
        switch (this.objectApiName) {
            case schema.userStory.objectApiName:
                return 'userStoryAlerts';
            case schema.feature.objectApiName:
                return 'featureAlerts';
            case schema.application.objectApiName:
                return 'applicationAlerts';
            default:
                return '';
        }
    }

    _searchTextInData(dataRows, searchText) {
        let result = [];

        result = dataRows.filter((eachRow) => {
            return Object.values(eachRow).some(function (value) {
                return value.toLowerCase().includes(searchText.toLowerCase());
            });
        });

        return result;
    }

    _getColumns() {
        return [
            {
                label: label.TestName,
                fieldName: 'testUrl',
                type: 'url',
                hideDefaultActions: true,
                typeAttributes: {
                    label: {
                        fieldName: 'name'
                    },
                    target: '_blank'
                }
            },
            { label: label.TestType, fieldName: 'testType', hideDefaultActions: true },
            { label: label.Tool, fieldName: 'testTool', hideDefaultActions: true },
            { label: label.RunDate, fieldName: 'runDate', hideDefaultActions: true },
            {
                label: label.Result,
                fieldName: 'resultUrl',
                type: 'url',
                hideDefaultActions: true,
                typeAttributes: {
                    label: {
                        fieldName: 'result'
                    },
                    target: '_blank'
                }
            },
            { label: label.Status, fieldName: 'status', hideDefaultActions: true, fixedWidth: 160 }
        ];
    }
}