import { LightningElement, api } from 'lwc';
import NAME from '@salesforce/schema/Static_Code_Analysis_Settings__c.Name';
import CODESCAN_TOKEN from '@salesforce/schema/Static_Code_Analysis_Settings__c.CodeScan_Token__c';
import CODESCAN_URL from '@salesforce/schema/Static_Code_Analysis_Settings__c.CodeScan_URL__c';
import CODESCAN_VERSION from '@salesforce/schema/Static_Code_Analysis_Settings__c.CodeScan_Version__c';
import { getFieldValue } from 'lightning/uiRecordApi';
import getStaticCodeAnalysisSettingById from '@salesforce/apex/GetStaticCodeAnalysis.getStaticCodeAnalysisSettingById';
import updateStaticCodeAnalysisSetting from '@salesforce/apex/GetStaticCodeAnalysis.updateStaticCodeAnalysisSetting';
//import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class Test_test extends LightningElement {
    @api objectApiName;
    @api recordId;
    //tetsing
    // nameField = NAME_FIELD;
    scaSettings;
    realFormData;

    async connectedCallback() {
        console.log('recordId ' + this.recordId);
        getStaticCodeAnalysisSettingById({ recordId: this.recordId })
            .then(result => {
                this.scaSettings = result;
                this.realFormData = { ...this.scaSettings };
                console.log('result: ' + this.result);
                console.log('result JSON: ' + JSON.stringify(this.result));
                /* PROBLEM: I want do more processing only when Apex returns an empty list, but result is always undefined */
                if (result === null || result === undefined) {
                    // Do some other actions
                }
            })
            .catch(error => {
                console.log('error ' + error.message);
            });
    }
    saveRecord() {
        updateStaticCodeAnalysisSetting({ con: this.realFormData }).then(() => {
            refreshApex(this.scaSettings);
        });
    }

    updateValue(event) {
        this.realFormData = { ...this.realFormData, [event.target.dataset.field]: event.detail.value };
        console.log(this.realFormData);
    }
    get token() {
        return getFieldValue(this.scaSettings, CODESCAN_TOKEN);
    }

    get url() {
        return getFieldValue(this.scaSettings, CODESCAN_URL);
    }

    get version() {
        return getFieldValue(this.scaSettings, CODESCAN_VERSION);
    }
    get name() {
        return getFieldValue(this.scaSettings, NAME);
    }
}