import { LightningElement, api } from 'lwc';
import NAME_FIELD from '@salesforce/schema/Static_Code_Analysis_Settings__c.Name';

export default class EditSCA extends LightningElement {
    @api objectApiName;
    @api recordId;
    //tetsing
    nameField = NAME_FIELD;
    @api invoke() {
        console.log("Hi, I'm an action.");
    }
}