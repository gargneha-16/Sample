import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import { showToastError } from 'c/copadocoreToastNotification';
import { autoFormValidation, handleAsyncError } from 'c/copadocoreUtils';

import search from '@salesforce/apex/CustomLookupComponentHelper.search';

import DATA_JSON_FIELD from '@salesforce/schema/JobStep__c.ConfigJson__c';
import NAME_FIELD from '@salesforce/schema/User.Name';

import Task_Description from '@salesforce/label/c.Task_Description';
import Task_Owner from '@salesforce/label/c.TASK_OWNER';
import Notify_Task_Owner from '@salesforce/label/c.NOTIFY_TASK_OWNER';
import Error_Searching_Records from '@salesforce/label/c.Error_Searching_Records';

export default class JobStepManual extends LightningElement {
    label = {
        Task_Description,
        Task_Owner,
        Notify_Task_Owner
    };

    notificationTypes = [
        { label: 'None', value: '' },
        { label: 'Email', value: 'Email' },
        { label: 'Chatter', value: 'Chatter' },
        { label: 'Email & Chatter', value: 'Email_Chatter' }
    ];

    @api stepId;
    @api configJson;

    selectedUserId;
    notificationType;
    taskDescription;

    @wire(getRecord, {
        recordId: '$selectedUserId',
        fields: [NAME_FIELD]
    })
    wiredUser(value) {
        const { data, error } = value;
        if (data) {
            const user = {
                Id: this.selectedUserId,
                Name: getFieldValue(data, NAME_FIELD)
            };
            
            const lookup = this.template.querySelector('c-lookup');
            if (lookup) {
                lookup.selection = [
                    {
                        Id: user.Id,
                        sObjectType: 'User',
                        icon: 'standard:choice',
                        title: user.Name,
                        subtitle: 'User • ' + user.Name
                    }
                ];
            }
        } else if (error) {
            showToastError(this, {
                message: error.body ? error.body.message : error.message
            });
            this.selectedFunction = undefined;
        }
    }

    connectedCallback() {
        this.parseData();
    }

    parseData() {
        if(this.configJson) {
            const config = JSON.parse(this.configJson);
            
            if(config.instructions) {
                this.taskDescription = config.instructions;
            }
            if(config.parameters) {
                this.parseParameters(config.parameters);
            }
        }
    }

    parseParameters(taskParameters) {
        taskParameters.forEach((parameter) => {
            if(parameter.name === 'ownerId') {
                this.selectedUserId = parameter.value;
            } else if(parameter.name === 'notificationType') {
                this.notificationType = parameter.value;
            }
        });
    }

    handleDescriptionChange(event) {
        this.taskDescription = event.target.value;
    }

    handleTypeChange(event) {
        this.notificationType = event.detail.value;
    }

    async handleLookupSearch(event) {
        const lookupElement = event.target;

        const safeSearch = handleAsyncError(this._search, {
            title: Error_Searching_Records
        });

        const queryConfig = {
            searchField: 'Name',
            objectName: 'User',
            searchKey: event.detail.searchTerm,
            extraFilterType: undefined,
            filterFormattingParameters: undefined
        };

        const result = await safeSearch(this, { queryConfig, objectLabel: 'User' });

        if (result) {
            lookupElement.setSearchResults(result);
        }
    }

    getSelectedId(lookupData) {
        if (lookupData.detail.length) {
            this.selectedUserId = lookupData.detail[0];
        } else {
            this.selectedUserId = undefined;
        }
    }

    @api
    getFieldsToSave() {
        const result = {};
        result[DATA_JSON_FIELD.fieldApiName] = JSON.stringify(this.generateDataJsonFieldValue());
        return result;
    }

    @api
    getAutoFormValidation() {
        return autoFormValidation(this.template, this);
    }

    @api
    getConfig() {
        return this.generateDataJsonFieldValue();
    }

    generateDataJsonFieldValue() {
        return {
            type: "Manual",
            configJson: {
                instructions : this.taskDescription,
                parameters: [
                    { name: 'ownerId', value: this.selectedUserId },
                    { name: 'notificationType', value: this.notificationType }
                ]
            }
        };
    }

    /**
     * Wrapper function with self (although unused) parameter so it can be used by handlerAsyncError
     */
     _search(self, queryConfig) {
        return search(queryConfig);
    }
}