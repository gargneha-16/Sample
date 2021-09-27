import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue, updateRecord } from 'lightning/uiRecordApi';

import { refreshApex } from '@salesforce/apex';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';

import { uniqueKey } from 'c/copadocoreUtils';

import ID_FIELD from '@salesforce/schema/Function__c.Id';
import PARAMETERS_FIELD from '@salesforce/schema/Function__c.Parameters__c';

import Function_Parameters from '@salesforce/label/c.Function_Parameters';
import Overwrite_Parameters from '@salesforce/label/c.Overwrite_Parameters';
import Parameters_Field_Help_Text from '@salesforce/label/c.Parameters_Field_Help_Text';
import Save from '@salesforce/label/c.Save';
import Add_new_parameter from '@salesforce/label/c.Add_new_parameter';

export default class FunctionsParametersContainer extends LightningElement {
    label = {
        Save,
        Add_new_parameter,
        Function_Parameters,
        Overwrite_Parameters,
        Parameters_Field_Help_Text
    };

    @api recordId;
    @track _target = '';
    @track _contextId = '';
    @track _overwriteParameters = '';

    selectedFunction;
    areDetailsVisible;
    parameters = [
        {
            id: uniqueKey('parameter'),
            parameterName: '',
            parameterValue: '',
            parameterRequired: false
        }
    ];

    // This variables are used to reset edited step information to the original value if modal is closed
    _originalSelectedFunctionId;
    _originalSelectedFunction;
    _originalParameters = [];

    @api
    get target() {
        return this._target;
    }

    set target(val) {
        this._target = val;
    }

    @api
    get contextId() {
        return this._contextId;
    }

    set contextId(val) {
        this._contextId = val;
    }

    @api
    get overwriteParameters() {
        return this._overwriteParameters;
    }

    set overwriteParameters(val) {
        this._overwriteParameters = val;
    }

    handleChangeContextId(event) {
        this._contextId = event.target.value;
    }

    showToastMessage(title, message, variant, mode) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: mode
        });
        this.dispatchEvent(evt);
    }

    parseDataIntoVariables(data) {
        const dataJsonValueObject = JSON.parse(getFieldValue(data, DATA_JSON_FIELD));
        if (dataJsonValueObject.functionParameters) {
            this.parseFunctionParametersIntoVariables(dataJsonValueObject.functionParameters);
        }
        this._originalSelectedFunctionId = dataJsonValueObject.functionId;
    }

    parseFunctionParametersIntoVariables(functionParameters) {
        const parameters = [];
        functionParameters.forEach(parameter => {
            parameters.push({
                id: uniqueKey('parameter'),
                parameterName: parameter.name,
                parameterValue: parameter.defaultValue || parameter.value,
                parameterRequired: parameter.required
            });
        });
        // JSON.parse(JSON.stringify()) is used in order to create a deep copy of the array
        this._originalParameters = JSON.parse(JSON.stringify(parameters));
        this.parameters = JSON.parse(JSON.stringify(parameters));
    }

    // If _originalSelectedFunctionId changes to actually be another valid function Id, the wiredOriginalFunction is called again
    // but if it is not actually an id, then it wiredOriginalFunction is not called
    @wire(getRecord, {
        recordId: '$_originalSelectedFunctionId',
        fields: [PARAMETERS_FIELD]
    })
    wiredOriginalFunction(value) {
        const { data, error } = value;
        if (data) {
            this.selectedFunction = this._originalSelectedFunction = {
                Id: this._originalSelectedFunctionId,
                Parameters: getFieldValue(data, PARAMETERS_FIELD)
            };

            this.parseFunctionParametersIntoVariables(JSON.parse(this.selectedFunction.Parameters));
        } else if (error) {
            this.showToastMessage('Application Error', error.body.output.errors[0].message, 'error', 'dismissable');
            this.selectedFunction = undefined;
        }
    }

    handleParameterChange(event) {
        const { index, parameter } = event.detail;
        this.parameters[index] = parameter;
    }

    handleAddParameter() {
        const newElement = {
            id: uniqueKey('parameter'),
            parameterName: '',
            parameterValue: '',
            parameterRequired: false
        };
        this.parameters = [...this.parameters, newElement];
    }

    handleDeleteParameter(event) {
        const { index } = event.detail;
        this.parameters.splice(index, 1);
        this.parameters = [...this.parameters]; //JSON.parse(JSON.stringify(this.parameters));
    }

    handleSave() {
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[PARAMETERS_FIELD.fieldApiName] = JSON.stringify(this.generateDataJSONFieldValue());
        const recordInput = { fields };
        updateRecord(recordInput)
            .then(() => {
                this.showToastMessage('Success', 'Parameters have been updated', 'success', 'dismissable');
                // Display fresh data in the form
                return refreshApex(this.contact);
            })
            .catch(error => {
                this.showToastMessage('Application Error', error.body.output.errors[0].message, 'error', 'dismissable');
            });
    }

    handleNext() {
        const contextIdAttributeChangeEvent = new FlowAttributeChangeEvent('contextId', this._contextId);
        this.dispatchEvent(contextIdAttributeChangeEvent);

        this._overwriteParameters = JSON.stringify(this.generateDataJSONFieldValueForExecution());
        const parametersAttributeChangeEvent = new FlowAttributeChangeEvent('overwriteParameters', this._overwriteParameters);
        this.dispatchEvent(parametersAttributeChangeEvent);

        const nextNavigationEvent = new FlowNavigationNextEvent();
        this.dispatchEvent(nextNavigationEvent);
    }

    generateDataJSONFieldValue() {
        const functionParameters = [];
        this.parameters.forEach(parameter => {
            functionParameters.push({
                name: parameter.parameterName,
                defaultValue: parameter.parameterValue,
                required: parameter.parameterRequired
            });
        });
        return functionParameters;
    }

    generateDataJSONFieldValueForExecution() {
        const functionParameters = [];
        this.parameters.forEach(parameter => {
            functionParameters.push({
                name: parameter.parameterName,
                value: parameter.parameterValue
            });
        });
        return functionParameters;
    }

    connectedCallback() {
        this._originalSelectedFunctionId = this.recordId;
        this.areDetailsVisible = this._target;
    }
}