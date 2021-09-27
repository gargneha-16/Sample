import { label, schema } from './constants';

const ADD_OPERATION_OPTION = { label: label.ADD, value: 'Add' };
const DELETE_OPERATION_OPTION = { label: label.DELETE, value: 'Delete' };
const FULL_OPERATION_OPTION = { label: 'Full', value: 'Full' };
const RETRIEVE_ONLY_OPERATION_OPTION = { label: label.RETRIEVE_ONLY, value: 'RetrieveOnly' };

export class DXCommitTable {
    getRowId(userStoryId, row) {
        return userStoryId + ';' + row.Directory + ';' + row.MemberType + ';' + row.MemberName;
    }

    parseUserStoryMetadata(records) {
        return records.map((record) => {
            const apiName = record[schema.METADATA_API_NAME_FIELD.fieldApiName];
            const apiNameHasDot = apiName.indexOf('.') !== -1;
            const type = record[schema.METADATA_TYPE_FIELD.fieldApiName];
            const action = record[schema.METADATA_ACTION_FIELD.fieldApiName];
            const directory = record[schema.METADATA_DIRECTORY_FIELD.fieldApiName];
            const lastModifiedDate = record.LastModifiedDate;
            const lastModifiedBy = record.LastModifiedBy;
            return {
                MemberName: apiName && apiNameHasDot ? apiName.substr(apiName.lastIndexOf('.') + 1) : apiName,
                MemberType: type || (apiName && apiNameHasDot ? apiName.substr(0, apiName.lastIndexOf('.')) : ''),
                Directory: directory,
                LastModifiedDate: lastModifiedDate,
                LastModifiedByName: lastModifiedBy ? lastModifiedBy.Name : '',
                Operation: action
            };
        });
    }

    createSelectedResult(row) {
        return {
            a: row.Operation,
            c: 'Copado Multi-Cloud', // TODO: hardcoded
            m: row.Directory, // TODO: directory is undefined at the moment
            n: row.MemberName,
            t: row.MemberType
        };
    }

    getColumns() {
        return [
            {
                label: label.OPERATION,
                fieldName: 'Operation',
                type: 'operation',
                typeAttributes: {
                    rowId: { fieldName: 'Id' },
                    options: { fieldName: 'OperationOptions' },
                    readOnlyMode: { fieldName: 'ReadOnlyMode' },
                    selectedCount: { fieldName: 'SelectedCount' }
                },
                searchable: true,
                sortable: true,
                initialWidth: 160,
                wrapText: true
            },
            { label: label.NAME, fieldName: 'MemberName', type: 'text', searchable: true, sortable: true },
            { label: label.TYPE, fieldName: 'MemberType', type: 'text', searchable: true, sortable: true, initialWidth: 150 },
            { label: label.DIRECTORY, fieldName: 'Directory', type: 'text', searchable: true, sortable: true, editable: true, initialWidth: 320 },
            { label: label.LAST_MODIFIED_DATE, fieldName: 'LastModifiedDate', type: 'date', searchable: true, sortable: true, initialWidth: 200 },
            { label: label.LAST_MODIFIED_BY, fieldName: 'LastModifiedByName', type: 'text', searchable: true, sortable: true, initialWidth: 200 }
        ];
    }

    getDefaultSortedByFieldName() {
        return 'MemberType';
    }

    getOperationOptions(row) {
        let operations = [ADD_OPERATION_OPTION, DELETE_OPERATION_OPTION];
        switch (row.MemberType) {
            case 'Profile':
            case 'PermissionSet':
                operations.push(FULL_OPERATION_OPTION);
                break;
            default:
                break;
        }
        operations.push(RETRIEVE_ONLY_OPERATION_OPTION);
        return operations;
    }
}