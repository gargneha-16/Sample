import { LightningElement, api } from 'lwc';

import { NavigationMixin } from 'lightning/navigation';

import getTestTypesInfo from '@salesforce/apex/CreateExtensionTestCtrl.getTestTypesInfo';

import TEST from '@salesforce/schema/Test__c';
import TEST_CATEGORY from '@salesforce/schema/Test__c.Category__c';
import TEST_TOOL from '@salesforce/schema/Test__c.Tool__c';
import TEST_USER_STORY from '@salesforce/schema/Test__c.User_Story__c';
import TEST_FEATURE from '@salesforce/schema/Test__c.Feature__c';
import TEST_APPLICATION from '@salesforce/schema/Test__c.Application__c';

import NewTestRecordModalTitle from '@salesforce/label/c.NewTestRecordModalTitle';
import Tool from '@salesforce/label/c.Tool';
import TestType from '@salesforce/label/c.TestType';
import ChooseTestType from '@salesforce/label/c.ChooseTestType';
import ChooseTestTool from '@salesforce/label/c.ChooseTestTool';
import Cancel from '@salesforce/label/c.Cancel';
import Save from '@salesforce/label/c.Save';

export default class CreateExtensionTest extends NavigationMixin(LightningElement) {
    @api recordId;

    objectApiName = TEST.objectApiName;
    categories = [];
    tools = [];
    labels = {
        NewTestRecordModalTitle,
        Tool,
        TestType,
        ChooseTestType,
        ChooseTestTool,
        Cancel,
        Save
    };
    fields = {
        TEST_USER_STORY,
        TEST_FEATURE,
        TEST_APPLICATION
    };

    _selectedCategory;
    _selectedTool;

    constructor() {
        super();
        console.log('this is constructor');

        console.log(document.referrer); // this is not working properly
    }

    async connectedCallback() {
        console.log(this.recordId);
        const testTypesInfo = await getTestTypesInfo();
        this.categories = testTypesInfo.categories;
        this.tools = testTypesInfo.tools;
    }

    renderedCallback() {
        console.log('this is redered callback');
    }

    // PUBLIC

    handleSelectedCategory(event) {
        this._selectedCategory = event.detail.value;
    }

    handleSelectedTool(event) {
        this._selectedTool = event.detail.value;
    }

    handleSubmit(event) {
        event.preventDefault();

        const fields = event.detail.fields;
        fields[TEST_CATEGORY.fieldApiName] = this._selectedCategory;
        fields[TEST_TOOL.fieldApiName] = this._selectedTool;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.mockPromise(); // 1º way of doing it with a promise NOTICE this should not happen when creating a new test from the test list view!

        // window.location = document.referrer; // 2º way - https://stackoverflow.com/questions/25639290/windows-history-back-location-reload-jquery

        // window.history.back();
        /*this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.detail.id,
                actionName: 'view'
            }
        });*/
    }

    handleCancel() {
        window.history.back();
        /*this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: TEST.objectApiName,
                actionName: 'list'
            }
        });*/
    }

    mockPromise() {
        return new Promise((resolve, reject) => {
            window.history.back();
            window.location.reload();
        });
    }
}