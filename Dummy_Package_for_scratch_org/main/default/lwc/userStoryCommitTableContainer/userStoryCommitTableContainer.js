import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { MessageContext, subscribe, publish } from 'lightning/messageService';

import { showToastError } from 'c/copadocoreToastNotification';
import { namespace, reduceErrors } from 'c/copadocoreUtils';
import { getSearchedData, getSortedData } from 'c/datatableService';

import { label } from './constants';
import {
    combineRows,
    createSelectedResult,
    parseUserStoryMetadata,
    prepareRows,
    getColumns,
    getDefaultSortedByFieldName,
    createDraftValue,
    upsertDraftValue
} from './utils';

import getUserStoryMetadata from '@salesforce/apex/UserStoryCommitCtrl.getUserStoryMetadata';

import COMMIT_PAGE_COMMUNICATION_CHANNEL from '@salesforce/messageChannel/CommitPageCommunication__c';

export default class UserStoryCommitTableContainer extends LightningElement {
    label = label;

    recordId;

    isLoading = false;

    // table
    keyField = 'Id'; // TODO: extensions should make sure this property exists in the data
    get columns() {
        return getColumns();
    }
    rows = [];
    allRows = [];
    filteredRows = [];
    previousSelectionRows = [];
    selectedRows = [];

    // sorting
    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    get sortedBy() {
        if (!this._sortedBy) {
            return getDefaultSortedByFieldName();
        }
        return this._sortedBy;
    }
    set sortedBy(value) {
        this._sortedBy = value;
    }
    _sortedBy;

    // searching
    searchTerm = '';

    // lazy loading
    _table;
    _batchSize = 50;
    _rowOffset = 0;
    _hasMoreData = false;

    // edit mode
    draftValues = [];

    get tableTitle() {
        return label.CHANGES;
    }

    get itemsTitle() {
        return this.selectedRows.length + ' ' + label.SELECTED;
    }

    get previousSelectionsToggleDisabled() {
        return !this.previousSelectionRows || this.previousSelectionRows.length === 0;
    }

    @wire(MessageContext)
    _context;

    @wire(CurrentPageReference)
    getParameters(pageReference) {
        if (pageReference && pageReference.state) {
            const parameterName = `${namespace || 'c__'}recordId`;
            this.recordId = pageReference.state[parameterName];
            // Note: if same app page is used but the US is different, reset all inputs
            this._resetInputs();
        }
    }

    @wire(getUserStoryMetadata, { recordId: '$recordId' })
    getPreviousSelections({ data, error }) {
        if (data) {
            let metadataRows = parseUserStoryMetadata(data);
            metadataRows = prepareRows(this.recordId, metadataRows, this.keyField);
            this.previousSelectionRows = [...metadataRows];
        } else if (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        }
    }

    connectedCallback() {
        this._subscribeToMessageService();
    }

    // TEMPLATE

    async handleTogglePreviousSelections() {
        try {
            this.isLoading = true;
            const checked = Array.from(this.template.querySelectorAll('[data-element="previous-selections-toggle"]')).some(
                (element) => element.checked
            );
            if (checked) {
                await this._addMetadataRowsToTable(this.previousSelectionRows);
                this._addMetadataToSelectedRows(this.previousSelectionRows);
            } else {
                await this._removeMetadataRowsFromTable(this.previousSelectionRows);
                this._removeMetadataFromSelectedRows(this.previousSelectionRows);
            }
        } catch (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        } finally {
            this.isLoading = false;
        }
    }

    handleSort(event) {
        try {
            this.isLoading = true;
            this.sortDirection = event.detail.sortDirection;
            this.sortedBy = event.detail.fieldName;
            const sortedData = this._applySort(this.rows, { name: this.sortedBy, sortDirection: this.sortDirection });
            this.rows = [...sortedData];
            // Note: without this the table is not re-rendering the select checkbox
            this.selectedRows = [...this.selectedRows];
        } catch (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        } finally {
            this.isLoading = false;
        }
    }

    handleClearSearch() {
        try {
            this.isLoading = true;
            this.searchTerm = '';
            this.filteredRows = [...this.allRows];
            const sortedData = this._applySort(this.filteredRows, { name: this.sortedBy, sortDirection: this.sortDirection });
            this.rows = [...sortedData];
            // Note: without this the table is not re-rendering the select checkbox
            this.selectedRows = [...this.selectedRows];
            this._rowOffset = this.rows.length;
            this._hasMoreData = this._rowOffset < sortedData.length;
        } catch (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        } finally {
            this.isLoading = false;
        }
    }

    handleApplySearch(event) {
        try {
            this.isLoading = true;
            const searchObj = event.detail;
            this.searchTerm = searchObj.searchTerm;
            this.filteredRows = [...searchObj.searchedData];
            const sortedData = this._applySort(this.filteredRows, { name: this.sortedBy, sortDirection: this.sortDirection });
            this.rows = [...sortedData];
            // Note: without this the table is not re-rendering the select checkbox
            this.selectedRows = [...this.selectedRows];
            this._rowOffset = this.rows.length;
            this._hasMoreData = this._rowOffset < sortedData.length;
        } catch (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        } finally {
            this.isLoading = false;
        }
    }

    handleRowSelection(event) {
        const selectedIds = new Set(event.detail.selectedRows.map((row) => row[this.keyField]));
        const currentIds = new Set(this.rows.map((row) => row[this.keyField]));

        let idsToBeSelected = new Set(this.selectedRows);

        selectedIds.forEach((id) => idsToBeSelected.add(id));

        currentIds.forEach((id) => {
            if (idsToBeSelected.has(id) && !selectedIds.has(id)) {
                idsToBeSelected.delete(id);
            }
        });

        this.selectedRows = [...idsToBeSelected];
        this._setSelectedCount();
    }

    handleLoadMore(event) {
        try {
            if (!this._hasMoreData) {
                return;
            }
            this._table = event.target;

            if (this._table) {
                this._table.isLoading = true;
            }
            // workaround to show spinner
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this._loadMore();
                if (this._table) {
                    this._table.isLoading = false;
                }
            });
        } catch (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        }
    }

    async handleSave(event) {
        try {
            this.isLoading = true;

            const newRows = [...this.allRows];

            event.detail.draftValues.forEach((updatedRow) => {
                const originalRowIndex = newRows.findIndex((originalRow) => originalRow[this.keyField] === updatedRow[this.keyField]);
                const originalRowWithUpdates = { ...newRows[originalRowIndex], ...updatedRow };
                newRows.splice(originalRowIndex, 1, originalRowWithUpdates);
            });

            await this._setRows(newRows);

            this._resetChanges();
        } catch (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this._resetChanges();
    }

    handleChangeDraftValue(event) {
        const rowId = event.detail.rowId;
        const property = event.detail.property;
        const value = event.detail.value;

        const newDraftValue = createDraftValue(rowId, property, value, this.keyField);
        const existingDraftValues = [...this.draftValues];
        this.draftValues = this._updateDraftValue(existingDraftValues, newDraftValue);

        this._setReadOnlyMode();
    }

    handleEditColumn(event) {
        const rowId = event.detail.rowId;
        const property = event.detail.property;
        const value = event.detail.value;

        const newRows = [...this.allRows];

        const originalRowIndex = newRows.findIndex((originalRow) => originalRow[this.keyField] === rowId);
        const originalRowWithUpdates = { ...newRows[originalRowIndex], ReadOnlyMode: false };
        newRows.splice(originalRowIndex, 1, originalRowWithUpdates);

        this._setRows(newRows);

        // Note: custom column needs to show the cancel in order to return to view mode
        const newDraftValue = createDraftValue(rowId, property, value, this.keyField);
        const existingDraftValues = [...this.draftValues];
        this.draftValues = this._updateDraftValue(existingDraftValues, newDraftValue);
    }

    handleCancelMultiEdit() {
        this._resetChanges();
    }

    handleChangeMultiDraftValue(event) {
        const rowId = event.detail.rowId;
        const property = event.detail.property;
        const value = event.detail.value;
        const updateSelected = event.detail.updateSelected;

        if (updateSelected) {
            let existingDraftValues = [...this.draftValues];
            this.selectedRows.forEach((selectedRowId) => {
                const newDraftValue = createDraftValue(selectedRowId, property, value, this.keyField);
                existingDraftValues = this._updateDraftValue(existingDraftValues, newDraftValue);
            });
            this.draftValues = existingDraftValues;
        } else {
            const newDraftValue = createDraftValue(rowId, property, value, this.keyField);
            const existingDraftValues = [...this.draftValues];
            this.draftValues = this._updateDraftValue(existingDraftValues, newDraftValue);
        }

        this._setReadOnlyMode();
    }

    // PRIVATE

    _subscribeToMessageService() {
        subscribe(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, (message) => this._handleCommitPageCommunicationMessage(message));
    }

    async _handleCommitPageCommunicationMessage(message) {
        try {
            this.isLoading = true;
            switch (message.type) {
                case 'request':
                    this._handleRequestMessage(message);
                    break;
                // extension
                case 'retrievedChanges':
                case 'pulledChanges':
                    await this._handleChangesMessage(message);
                    break;
                default:
            }
        } catch (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        } finally {
            this.isLoading = false;
        }
    }

    _handleRequestMessage() {
        const selectedChanges = this._getSelectedChanges();
        const payload = {
            type: 'changes',
            value: selectedChanges
        };
        publish(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, payload);
    }

    async _handleChangesMessage(message) {
        const metadatas = message.value;
        const metadataRows = prepareRows(this.recordId, metadatas, this.keyField);
        await this._addMetadataRowsToTable(metadataRows);
    }

    async _addMetadataRowsToTable(metadataRows) {
        const combinedRows = combineRows(this.allRows, metadataRows, this.keyField);
        await this._setRows(combinedRows);
    }

    async _removeMetadataRowsFromTable(metadataRows) {
        const difference = this.allRows.filter(
            (row) => metadataRows.some((metadataRow) => row[this.keyField] === metadataRow[this.keyField]) === false
        );
        await this._setRows(difference);
    }

    _addMetadataToSelectedRows(rows) {
        const newSelections = rows.map((element) => element[this.keyField]);
        this.selectedRows = [...this.selectedRows, ...newSelections];
    }

    _removeMetadataFromSelectedRows(rows) {
        const newSelections = this.selectedRows.filter((rowId) => rows.some((metadataRow) => rowId === metadataRow[this.keyField]) === false);
        this.selectedRows = [...newSelections];
    }

    async _setRows(rows) {
        this.allRows = [...rows];
        this.filteredRows = await this._applySearch(this.allRows);
        const sortedData = this._applySort(this.filteredRows, { name: this.sortedBy, sortDirection: this.sortDirection });
        this.rows = [...sortedData].slice(0, this._rowOffset + this._batchSize);
        this._rowOffset = this.rows.length;
        this._hasMoreData = this._rowOffset < sortedData.length;
    }

    _getSelectedChanges() {
        return this.selectedRows.map((metadataId) => {
            const selectedRow = this.allRows.find((row) => metadataId === row[this.keyField]);
            let result = {};
            if (selectedRow) {
                result = createSelectedResult(selectedRow);
            }
            return result;
        });
    }

    _applySort(rows, sortConfiguration) {
        return rows && rows.length ? getSortedData(this.columns, rows, sortConfiguration) : rows;
    }

    async _applySearch(rows) {
        let result = [];
        if (this.searchTerm.length < 3) {
            result = [...rows];
        } else {
            const filteredRawData = await getSearchedData(this.columns, rows, this.searchTerm);
            if (filteredRawData) {
                result = [...filteredRawData];
            } else {
                result = [...rows];
            }
        }
        return result;
    }

    _loadMore() {
        const rows = [...this.filteredRows];
        const sortedData = this._applySort(rows, { name: this.sortedBy, sortDirection: this.sortDirection });
        if (this._rowOffset < sortedData.length) {
            const moreData = sortedData.slice(0, this._rowOffset + this._batchSize);
            if (moreData && moreData.length) {
                this.rows = [...moreData];
                // Note: without this the table is not re-rendering the select checkbox
                this.selectedRows = [...this.selectedRows];
                this._rowOffset = this.rows.length;
                this._hasMoreData = this._rowOffset < sortedData.length;
            }
        } else {
            this._hasMoreData = false;
        }
    }

    // this will return the list of updated draft values, but not set the list on the table or the global array to improve performance
    _updateDraftValue(draftValues, newDraftValue) {
        const table = this.template.querySelector('c-user-story-commit-table');
        if (table) {
            table.draftValues.forEach((draftValue) => {
                draftValues = upsertDraftValue(draftValues, draftValue, this.keyField);
            });
        }
        draftValues = upsertDraftValue(draftValues, newDraftValue, this.keyField);
        if (table) {
            table.draftValues = draftValues;
        }
        return draftValues;
    }

    _resetChanges() {
        this.draftValues = [];
        this._setReadOnlyMode();
    }

    _setReadOnlyMode() {
        this.allRows = this.allRows.map((row) => {
            return { ...row, ReadOnlyMode: true };
        });
        this.filteredRows = this.allRows.map((row) => {
            return { ...row, ReadOnlyMode: true };
        });
        this.rows = this.rows.map((row) => {
            return { ...row, ReadOnlyMode: true };
        });
    }

    _setSelectedCount() {
        const selectedCount = this.selectedRows.length;
        this.allRows.forEach((row) => {
            row.SelectedCount = selectedCount;
        });
        this.filteredRows.forEach((row) => {
            row.SelectedCount = selectedCount;
        });
        this.rows.forEach((row) => {
            row.SelectedCount = selectedCount;
        });
    }

    _resetInputs() {
        this.rows = [];
        this.allRows = [];
        this.filteredRows = [];
        this.previousSelectionRows = [];
        this.selectedRows = [];

        this.template.querySelectorAll('[data-element="previous-selections-toggle"]').forEach((element) => {
            if (element) {
                element.checked = false;
            }
        });

        this.defaultSortDirection = 'asc';
        this.sortDirection = 'asc';
        this._sortedBy = null;

        this.searchTerm = '';

        this._table = null;
        this._batchSize = 50;
        this._rowOffset = 0;
        this._hasMoreData = false;

        this.draftValues = [];
    }
}