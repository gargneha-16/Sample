import { LightningElement, api } from 'lwc';
import getAttachment from '@salesforce/apex/ReadFromAttachmentCtrl.getAttachment';
import { handleAsyncError } from 'c/copadocoreUtils';

const columns = [
    { label: 'fileType', fieldName: 'fileType', type: 'text' }
   
];

export default class ReadFromAttachment extends LightningElement {
    // Required
    @api recordId;
    @api name;
    columns = columns;
    data = [];

    showSpinner;

    async connectedCallback() {
        const safeGetAttachment = handleAsyncError(this._getAttachment, { title: 'Error' });
        alert('test-->');

        const result = await safeGetAttachment(this, { parentId: this.recordId, name: this.name });
       console.log('result'+JSON.stringify(result));
        if (result) {
            console.log('result'+JSON.parse(atob(result)));
            this.data = JSON.parse(atob(result));
        }
    }

    _getAttachment(self, params) {
        return getAttachment(params);
    }
}