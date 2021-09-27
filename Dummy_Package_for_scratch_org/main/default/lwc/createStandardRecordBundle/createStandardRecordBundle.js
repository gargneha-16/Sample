import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { handleAsyncError } from 'c/copadocoreUtils';

import getSupportedObjects from '@salesforce/apex/CreateStandardRecordCtrl.getSupportedObjects';
import getRecordBundle from '@salesforce/apex/CreateStandardRecordCtrl.getRecordBundle';
import search from '@salesforce/apex/CustomLookupComponentHelper.search';

import NAME from '@salesforce/label/c.NAME';
import DELETE from '@salesforce/label/c.DELETE';
import ObjectType from '@salesforce/label/c.ObjectType';

import SelectObject from '@salesforce/label/c.SelectObject';
import SelectRecord from '@salesforce/label/c.SelectRecord';
import CreateExtension from '@salesforce/label/c.CreateExtensionTab';
import COPY_TO_CLIPBOARD from '@salesforce/label/c.COPY_TO_CLIPBOARD';

import CreateExtensionInstruction from '@salesforce/label/c.CreateExtensionInstruction';

import Error_Searching_Records from '@salesforce/label/c.Error_Searching_Records';

export default class CreateStandardRecordBundle extends LightningElement {
    selectedObject;
    isLoading = false;
    serializedBundle;

    _supportedObjects;
    _uniqueSelectedRecords = new Set();
    copied = false;

    @track
    _selectedRecords = [];

    _lastResults;

    label = {
        SelectObject,
        SelectRecord,
        CreateExtension,
        COPY_TO_CLIPBOARD,
        CreateExtensionInstruction
    };

    columns = [
        {
            label: NAME,
            fieldName: 'recordLink',
            type: 'url',
            typeAttributes: { label: { fieldName: 'recordName' }, target: '_blank' }
        },
        {
            label: ObjectType,
            fieldName: 'objectType'
        },
        {
            type: 'action',
            typeAttributes: { rowActions: [{ label: DELETE, name: 'Delete' }] }
        }
    ];

    async connectedCallback() {
        this.isLoading = true;
        try {
            this._supportedObjects = await getSupportedObjects();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get selectedRecords() {
        const selectedRecords = this._selectedRecords || [];

        return selectedRecords.map((selectedRecord) => ({ ...selectedRecord, recordLink: '/' + selectedRecord.recordId }));
    }

    get selectedObjectLabel() {
        return this.supportedObjects.find((supportedObject) => supportedObject.value === this.selectedObject)?.label;
    }

    get supportedObjects() {
        return this._supportedObjects || [];
    }

    get isLookupDisabled() {
        return !Boolean(this.selectedObject);
    }

    get hasNoSelectedRecords() {
        return !Boolean(this.selectedRecords.length);
    }

    get hasSelectedRecords() {
        return Boolean(this.selectedRecords.length);
    }

    get copyIcon() {
        return this.copied ? 'utility:check' : 'utility:copy';
    }

    copyToClipboard() {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(this.serializedBundle);
        } else {
            this.fallbackCopyToClipboard(this.serializedBundle);
        }

        this.copied = true;
        setTimeout(() => {
            this.copied = false;
        }, 1500);
    }

    fallbackCopyToClipboard(text) {
        const textArea = document.createElement('textarea');
        textArea.value = text;

        // Avoid scrolling to bottom
        textArea.style.top = '0';
        textArea.style.left = '0';
        textArea.style.position = 'fixed';

        document.body.appendChild(textArea);
        textArea.focus();
        textArea.select();

        try {
            document.execCommand('copy');
        } catch (err) {
            this.showError(err);
        }

        document.body.removeChild(textArea);
    }

    selectObject(event) {
        this.selectedObject = event.detail.value;
    }

    async handleLookupSearch(event) {
        const lookupElement = event.target;

        const safeSearch = handleAsyncError(this._search, {
            title: Error_Searching_Records
        });

        const queryConfig = {
            searchField: 'Name',
            objectName: this.selectedObject,
            searchKey: event.detail.searchTerm,
            extraFilterType: undefined,
            filterFormattingParameters: undefined
        };

        this._lastResults = await safeSearch(this, { queryConfig, objectLabel: this.selectedObjectLabel });

        if (this._lastResults) {
            lookupElement.setSearchResults(this._lastResults);
        }
    }

    addToSelectedRecord(event) {
        if (event.detail.length && !this._uniqueSelectedRecords.has(event.detail[0])) {
            this._selectedRecords.push({
                recordId: event.detail[0],
                recordName: this._lastResults.find((el) => el.id === event.detail[0]).title,
                objectType: this.selectedObjectLabel
            });
            this._uniqueSelectedRecords.add(event.detail[0]);

            this.template.querySelector('c-lookup').handleClearSelection();
        } else if (event.detail[0] && this._uniqueSelectedRecords.has(event.detail[0])) {
            this.template.querySelector('c-lookup').handleClearSelection();
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;

        if (actionName === 'Delete') {
            const { recordId } = event.detail.row;
            const selectedRowIndex = this._selectedRecords.findIndex((record) => record.recordId === recordId);

            this._selectedRecords.splice(selectedRowIndex, 1);
            this._uniqueSelectedRecords.delete(recordId);
        }
    }

    async getRecordBundle() {
        this.isLoading = true;

        try {
            const serializedBundle = await getRecordBundle({ recordIds: this.selectedRecords.map((selectedRecord) => selectedRecord.recordId) });
            this.serializedBundle = JSON.stringify(this.bundleWithNamespace(serializedBundle), null, 2);
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    bundleWithNamespace(serializedBundle) {
        const bundle = JSON.parse(serializedBundle);

        return {
            ...bundle,
            RecordSetBundles: this.addNamespaceToBundle(bundle.RecordSetBundles),
            recordTypeMap: this.addNamespaceTyRecordTypeMap(bundle.recordTypeMap)
        };
    }

    addNamespaceTyRecordTypeMap(recordTypeMap) {
        const result = {};

        for (const recordTypeId in recordTypeMap) {
            result[recordTypeId] = {
                ...recordTypeMap[recordTypeId],
                SobjectType: this.withPrefix(recordTypeMap[recordTypeId].SobjectType)
            };
        }

        return result;
    }

    addNamespaceToBundle(bundles) {
        const result = bundles.map((bundle) => {
            const ObjectType = this.withPrefix(bundle.ObjectType);
            const Records = bundle.Records.map((record) => {
                const result = {};

                for (const field in record) {
                    if (field === 'attributes') {
                        result[field] = {
                            type: this.withPrefix(record[field].type),
                            url: this.urlWithPrefix(record[field].url)
                        };
                    } else {
                        const updatedFieldName = this.withPrefix(field);
                        result[updatedFieldName] = record[field];
                    }
                }

                return result;
            });

            return { Records, ObjectType };
        });

        return result;
    }

    urlWithPrefix(url) {
        return !url.includes('copado__') ? url.replace('sobjects/', 'sobjects/copado__') : url;
    }

    withPrefix(text) {
        return text.endsWith('__c') && !text.startsWith('copado__') ? 'copado__' + text : text;
    }

    showError(error) {
        const title = error?.body?.exceptionType || 'Error';
        const message = error?.body?.message || error?.message || error;

        this.showToast(title, message);
    }

    showToast(title, message, variant = 'error') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /**
     * Wrapper function with self (although unused) parameter so it can be used by handlerAsyncError
     */
    _search(self, queryConfig) {
        return search(queryConfig);
    }
}