import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import { showToastError } from 'c/copadocoreToastNotification';
import { autoFormValidation, uniqueKey, handleAsyncError } from 'c/copadocoreUtils';

import search from '@salesforce/apex/CustomLookupComponentHelper.search';
import getFunctionsByApiName from '@salesforce/apex/FunctionsSelector.getFunctionsByApiName';

import DATA_JSON_FIELD from '@salesforce/schema/JobStep__c.ConfigJson__c';
import NAME_FIELD from '@salesforce/schema/Function__c.Name';
import PARAMETERS_FIELD from '@salesforce/schema/Function__c.Parameters__c';
import API_NAME_FIELD from '@salesforce/schema/Function__c.API_Name__c';
import Function from '@salesforce/label/c.Function';
import Function_Parameters from '@salesforce/label/c.Function_Parameters';
import Function_Parameters_Helptext from '@salesforce/label/c.Function_Parameters_Helptext';
import Parameter_Name from '@salesforce/label/c.Parameter_Name';
import Parameter_Name_Placeholder from '@salesforce/label/c.Parameter_Name_Placeholder';
import Parameter_Value from '@salesforce/label/c.Parameter_Value';
import Parameter_Value_Placeholder from '@salesforce/label/c.Parameter_Value_Placeholder';
import DELETE from '@salesforce/label/c.DELETE';
import Add_new_parameter from '@salesforce/label/c.Add_new_parameter';
import Error_Searching_Records from '@salesforce/label/c.Error_Searching_Records';

export default class JobStepFunction extends LightningElement {
    label = {
        Function,
        Function_Parameters,
        Function_Parameters_Helptext,
        Parameter_Name,
        Parameter_Name_Placeholder,
        Parameter_Value,
        Parameter_Value_Placeholder,
        DELETE,
        Add_new_parameter
    };

    @api currentFunctionId;
    @api stepId;
    @api configJson;

    oldFunctionAPIName;
    selectedFunctionId;
    selectedFunction;
    lookupHasChanged = false;
    modalMode = 'new';
    parameters = [
        {
            id: uniqueKey('parameter'),
            parameterName: '',
            parameterValue: ''
        }
    ];

    get uniqueKey() {
        return uniqueKey('parameter');
    }

    connectedCallback() {
        this.parseData();
    }

    parseData() {
        if(this.configJson) {
            const config = JSON.parse(this.configJson);
            
            if(!this.oldFunctionAPIName) {
                this.oldFunctionAPIName = config.functionName;
            }
            if(config.parameters) {
                this.parseParameters(config.parameters);
            }

            this.getFunctionDetailsFromApiName(config.functionName);
        }
    }

    getFunctionDetailsFromApiName(apiName) {
        getFunctionsByApiName({ functionApiName: apiName })
            .then((result) => {
                if (result && result.length > 0) {
                    this.selectedFunctionId = result[0].Id;
                }
            })
            .catch((error) => {
                showToastError(this, {
                    message: error.body ? error.body.message : error.message
                });
            });
    }

    parseParameters(functionParameters) {
        const parameters = [];
        functionParameters.forEach((parameter) => {
            parameters.push({
                id: uniqueKey('parameter'),
                parameterName: parameter.name,
                parameterValue: parameter.defaultValue || parameter.value,
                parameterRequired: parameter.required
            });
        });
        
        this.parameters = JSON.parse(JSON.stringify(parameters));
    }

    @wire(getRecord, {
        recordId: '$selectedFunctionId',
        fields: [NAME_FIELD, PARAMETERS_FIELD, API_NAME_FIELD]
    })
    wiredFunction(value) {
        const { data, error } = value;
        
        if(data) {
            console.log("function data", data);
            this.initFunction(data);

            this.modalMode = this.stepId ? 'edit' : 'new';
            if((this.modalMode === 'new' || this.oldFunctionAPIName !== this.selectedFunction.ApiName ||
                (this.modalMode === 'edit' && this.oldFunctionAPIName === this.selectedFunction.ApiName && this.lookupHasChanged)) &&
                this.selectedFunction.Parameters) {
                this.parseParameters(JSON.parse(this.selectedFunction.Parameters));
            }

            this.initLookup();
        } else if (error) {
            showToastError(this, {
                message: error.body ? error.body.message : error.message
            });
            this.selectedFunction = undefined;
        }
    }

    initFunction(data) {
        this.selectedFunction = {
            Id: data.id,
            Name: getFieldValue(data, NAME_FIELD),
            Parameters: getFieldValue(data, PARAMETERS_FIELD),
            ApiName: getFieldValue(data, API_NAME_FIELD)
        };
    }

    initLookup() {
        const lookup = this.template.querySelector('c-lookup');

        if(lookup) {
            lookup.selection = [{
                Id: this.selectedFunction.Id,
                sObjectType: 'Function',
                icon: 'standard:choice',
                title: this.selectedFunction.Name,
                subtitle: 'API Name: ' + this.selectedFunction.ApiName
            }];
        }
    }

    async handleLookupSearch(event) {
        const lookupElement = event.target;

        const safeSearch = handleAsyncError(this._search, {
            title: Error_Searching_Records
        });

        const queryConfig = {
            searchField: 'Name',
            objectName: 'Function__c',
            searchKey: event.detail.searchTerm,
            extraFilterType: undefined,
            filterFormattingParameters: undefined
        };

        const result = await safeSearch(this, { queryConfig, objectLabel: 'Function' });

        if (result) {
            lookupElement.setSearchResults(result);
        }
    }

    getSelectedId(lookupData) {
        if (lookupData.detail.length) {
            this.lookupHasChanged = true;
            this.selectedFunctionId = lookupData.detail[0];
        } else {
            this.selectedFunction = undefined;
        }
    }

    handleParameterChange(event) {
        const parameterId = event.target.dataset.id;
        const index = this.parameters.findIndex((parameter) => parameter.id === parameterId);
        this.parameters[index][event.target.name] = event.detail.value;
    }

    handleAddParameter() {
        const newElement = {
            id: uniqueKey('parameter'),
            parameterName: '',
            parameterValue: ''
        };
        this.parameters = [...this.parameters, newElement];
    }

    handleDeleteParameter(event) {
        const parameterId = event.target.dataset.id;
        this.parameters = this.parameters.filter((parameter) => parameter.id !== parameterId);
    }

    @api
    getFieldsToSave() {
        const fields = {};
        fields[DATA_JSON_FIELD.fieldApiName] = JSON.stringify(this.generateDataJsonFieldValue());
        return fields;
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
        const functionParameters = [];
        this.parameters.forEach((parameter) => {
            if(parameter.parameterName) {
                functionParameters.push({
                    name: parameter.parameterName,
                    value: parameter.parameterValue
                });
            }
        });

        return {
            type: "Function",
            configJson: {
                functionName: this.selectedFunction ? this.selectedFunction.ApiName : '',
                parameters: functionParameters
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