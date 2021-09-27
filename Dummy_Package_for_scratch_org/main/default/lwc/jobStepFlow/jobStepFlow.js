import { LightningElement, api, wire } from 'lwc';

import { showToastError } from 'c/copadocoreToastNotification';
import { autoFormValidation, uniqueKey } from 'c/copadocoreUtils';

import DATA_JSON_FIELD from '@salesforce/schema/JobStep__c.ConfigJson__c';

import getFlowsAvailableForExecution from '@salesforce/apex/DeploymentStepsUtils.getFlowsAvailableForExecution';

import Flow_Step_Execution_Action_Option_Helptext from '@salesforce/label/c.Flow_Step_Execution_Action_Option_Helptext';
import Salesforce_Flow_Parameters_Helptext from '@salesforce/label/c.Salesforce_Flow_Parameters_Helptext';
import SALESFORCE_FLOW from '@salesforce/label/c.SALESFORCE_FLOW';
import Salesforce_Flow_Placeholder from '@salesforce/label/c.Salesforce_Flow_Placeholder';
import Flow_Step_Pause from '@salesforce/label/c.Flow_Step_Pause';
import Salesforce_Flow_Parameters_Title from '@salesforce/label/c.Salesforce_Flow_Parameters_Title';
import Parameter_Name from '@salesforce/label/c.Parameter_Name';
import Parameter_Name_Placeholder from '@salesforce/label/c.Parameter_Name_Placeholder';
import Parameter_Value from '@salesforce/label/c.Parameter_Value';
import Parameter_Value_Placeholder from '@salesforce/label/c.Parameter_Value_Placeholder';
import DELETE from '@salesforce/label/c.DELETE';
import Add_new_parameter from '@salesforce/label/c.Add_new_parameter';

const _booleanElements = ['checkbox', 'checkbox-button', 'toggle'];

export default class JobStepFlow extends LightningElement {
    label = {
        Flow_Step_Execution_Action_Option_Helptext,
        Salesforce_Flow_Parameters_Helptext,
        SALESFORCE_FLOW,
        Salesforce_Flow_Placeholder,
        Flow_Step_Pause,
        Salesforce_Flow_Parameters_Title,
        Parameter_Name,
        Parameter_Name_Placeholder,
        Parameter_Value,
        Parameter_Value_Placeholder,
        DELETE,
        Add_new_parameter
    };

    @api stepId;
    @api configJson;

    flowsAvailableForExecution;
    selectedFlow;
    pauseStepAfterExecution = true;
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

    @wire(getFlowsAvailableForExecution)
    wiredFlowsAvailableForExecution(value) {
        const { data, error } = value;
        if (data) {
            const rawFlows = JSON.parse(data);
            this.flowsAvailableForExecution = rawFlows.map(({ flowLabel, flowApiName }) => ({ label: flowLabel, value: flowApiName }));
        } else if (error) {
            showToastError(this, {
                message: error.body ? error.body.message : error.message
            });
            console.error(error);
            this.flowsAvailableForExecution = undefined;
        }
    }

    connectedCallback() {
        this.parseData();
    }

    parseData() {
        if(this.configJson) {
            const config = JSON.parse(this.configJson);
            
            if(config.flowName) {
                this.selectedFlow = config.flowName;
            }

            if(config.parameters) {
                this.parseParameters(config.parameters);
            }
        }
    }

    parseParameters(flowParameters) {
        const parameters = [];
        flowParameters.forEach((parameter) =>
            parameters.push({
                id: uniqueKey('parameter'),
                parameterName: parameter.name,
                parameterValue: parameter.value
            })
        );
        
        this.parameters = JSON.parse(JSON.stringify(parameters));
    }

    handleChange(event) {
        if (_booleanElements.includes(event.target.type)) {
            this[event.target.name] = event.target.checked;
        } else {
            this[event.target.name] = event.target.value;
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
        const flowParameters = [
            {
                name: "type",
                value: this.pauseStepAfterExecution ? 'wait' : 'continue'
            }
        ];
        this.parameters.forEach((parameter) => {
            if(parameter.parameterName) {
                flowParameters.push({
                    name: parameter.parameterName, 
                    value: parameter.parameterValue
                });
            }
        });

        return {
            type: "Flow",
            configJson: {
                flowName: this.selectedFlow,
                parameters: flowParameters
            }
        };
    }
}