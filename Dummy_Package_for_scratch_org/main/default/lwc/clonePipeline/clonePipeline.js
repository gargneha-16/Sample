import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowAttributeChangeEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';

import getData from '@salesforce/apex/ClonePipeline.getData';
import saveCopy from '@salesforce/apex/ClonePipeline.saveCopy';

import DEPLOYMENT_FLOW from '@salesforce/schema/Deployment_Flow__c';

import PIPELINE_NAME from '@salesforce/schema/Deployment_Flow__c.Name';
import GIT_REPOSITORY from '@salesforce/schema/Deployment_Flow__c.Git_Repository__c';
import MAIN_BRANCH from '@salesforce/schema/Deployment_Flow__c.Main_Branch__c';
import SOURCE_ENVIRONMENT from '@salesforce/schema/Deployment_Flow_Step__c.Source_Environment__c';
import STEP_BRANCH from '@salesforce/schema/Deployment_Flow_Step__c.Branch__c';

import ERROR from '@salesforce/label/c.ERROR';
import SUCCESS from '@salesforce/label/c.SUCCESS';
import SAVE from '@salesforce/label/c.Save';
import CLOSE from '@salesforce/label/c.CLOSE';
import PIPELINE_CLONED from '@salesforce/label/c.Pipeline_Cloned';
import PIPELINE_DETAILS from '@salesforce/label/c.Pipeline_Details';
import ENVIRONMENT_NAMES from '@salesforce/label/c.Environment_Names';
import NAME from '@salesforce/label/c.NAME';
import BRANCH from '@salesforce/label/c.BRANCH';
import PLATFORM_MISSING from '@salesforce/label/c.Pipeline_Platform_Missing';

export default class ClonePipeline extends LightningElement {
    apiNames = {
        PIPELINE: DEPLOYMENT_FLOW.objectApiName,
        PIPELINE_NAME: PIPELINE_NAME.fieldApiName,
        GIT_REPOSITORY: GIT_REPOSITORY.fieldApiName,
        MAIN_BRANCH: MAIN_BRANCH.fieldApiName
    };

    label = {
        SAVE,
        CLOSE,
        PIPELINE_DETAILS,
        ENVIRONMENT_NAMES,
        NAME,
        BRANCH,
        PLATFORM_MISSING
    };

    @api recordId;
    @api cloneId;

    data;
    environments = [];
    loading = true;

    get hasConnections() {
        return this.environments.length > 0;
    }

    get isSalesforce() {
        return String(this.data?.platform) === "Salesforce";
    }

    get hasPlatform() {
        return Boolean(this.data?.platform);
    }

    async connectedCallback() {
        this.data = JSON.parse(await getData({ recordId: this.recordId }));
        this.initConnections();
        this.loading = false;
    }

    renderedCallback() {
        this.initPipelineInputs();
    }

    initPipelineInputs() {
        const pipeline = this.data?.pipeline;

        this.template.querySelectorAll("lightning-input-field")?.forEach(input => {
            if(input.fieldName === "Name") {
                input.value = "Clone of " + String(pipeline?.Name);
            } else if(input.fieldName === GIT_REPOSITORY.fieldApiName) {
                input.value = pipeline[GIT_REPOSITORY.fieldApiName];
            } else if(input.fieldName === MAIN_BRANCH.fieldApiName) {
                input.value = pipeline[MAIN_BRANCH.fieldApiName];
            }
        });
    }

    initConnections() {
        let branchesBySource = this.branchesBySource();

        this.data?.environments?.forEach(record => {
            this.environments.push({
                id: record.Id,
                name: record.Name,
                branch: branchesBySource.get(record.Id),
                isSource: branchesBySource.has(record.Id)
            });
        });

        this.environments?.sort((a, b) => a.isSource - b.isSource);
    }

    branchesBySource() {
        let result = new Map();

        this.data?.connections?.forEach(connection => {
            result.set(connection[SOURCE_ENVIRONMENT.fieldApiName], connection[STEP_BRANCH.fieldApiName]);
        });

        return result;
    }

    async save() {
        this.loading = true;

        this.getInputValues();

        try {
            const cloneId = await saveCopy({ data: JSON.stringify(this.data) });
            this.showToast(SUCCESS, PIPELINE_CLONED, 'success');

            const attributeChangeEvent = new FlowAttributeChangeEvent('cloneId', cloneId);
            this.dispatchEvent(attributeChangeEvent);

            const navigateNextEvent = new FlowNavigationNextEvent();
            this.dispatchEvent(navigateNextEvent);
        } catch(error) {
            console.error('error', error.body.message);
            this.showToast(ERROR, error.body.message);
        }
        
        this.loading = false;
    }

    getInputValues() {
        this.template.querySelectorAll("lightning-input-field")?.forEach(input => {
            if(input.fieldName === "Name") {
                this.data.pipeline.Name = input.value;
            } else if(input.fieldName === GIT_REPOSITORY.fieldApiName) {
                this.data.pipeline[GIT_REPOSITORY.fieldApiName] = input.value;
            } else if(input.fieldName === MAIN_BRANCH.fieldApiName) {
                this.data.pipeline[MAIN_BRANCH.fieldApiName] = input.value;
            }
        });
    }

    handleEnvironmentNameChange(event) {
        let environment = this.data.environments.filter(record => {
            return record.Id === event.target.dataset.id;
        })[0];

        environment.Name = event.target.value;
    }

    handleConnectionBranchChange(event) {
        let connection = this.data.connections.filter(record => {
            return record[SOURCE_ENVIRONMENT.fieldApiName] === event.target.dataset.id;
        })[0];

        connection[STEP_BRANCH.fieldApiName] = event.target.value;
    }

    showToast(title, message, variant = 'error') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}