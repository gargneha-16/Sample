import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { MessageContext, subscribe, publish } from 'lightning/messageService';

import { namespace, handleAsyncError } from 'c/copadocoreUtils';

import editBaseBranchAvailable from '@salesforce/customPermission/Edit_User_Story_Commit_Base_Branch';

import reCreateFeatureBranchAvailable from '@salesforce/apex/UserStoryCommitCtrl.isReCreateFeatureBranchAvailable';

import COMMIT_PAGE_COMMUNICATION_CHANNEL from '@salesforce/messageChannel/CommitPageCommunication__c';

import NAME from '@salesforce/schema/User_Story__c.Name';
import TITLE from '@salesforce/schema/User_Story__c.User_Story_Title__c';

import LOADING from '@salesforce/label/c.LOADING';
import GitOperations from '@salesforce/label/c.GitOperations';
import TypeCommitMessage from '@salesforce/label/c.TypeCommitMessage';
import Commit_Message from '@salesforce/label/c.Commit_Message';
import ReCreateFeatureBranch from '@salesforce/label/c.ReCreateFeatureBranch';
import ChangeBaseBranch from '@salesforce/label/c.ChangeBaseBranch';
import Enabled from '@salesforce/label/c.Enabled';
import Disabled from '@salesforce/label/c.Disabled';
import SelectBaseBranch from '@salesforce/label/c.SelectBaseBranch';
import SearchBranches from '@salesforce/label/c.SearchBranches';

export default class UserStoryCommitBody extends LightningElement {
    label = {
        LOADING,
        GitOperations,
        TypeCommitMessage,
        Commit_Message,
        ReCreateFeatureBranch,
        ChangeBaseBranch,
        Enabled,
        Disabled,
        SelectBaseBranch,
        SearchBranches
    }

    showSpinner;

    editBaseBranchAvailable = editBaseBranchAvailable;
    reCreateFeatureBranchAvailable;

    commitMessage;
    reCreate;
    changeBaseBranch;
    baseBranch;

    @wire(MessageContext)
    _context;

    // These variables, although "private", do not start with '_'
    recordId;

    @wire(CurrentPageReference)
    getParameters(pageReference) {
        if (pageReference && pageReference.state) {
            const parameterName = `${(namespace || 'c__')}recordId`;
            this.recordId = pageReference.state[parameterName];
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [NAME, TITLE] })
    wiredRecord({ error, data }) {
        if (error) {
            console.error(error);
        } else if (data) {
            this.commitMessage = `${getFieldValue(data, NAME)} ${getFieldValue(data, TITLE)}`;
        }
    }

    // TODO: how do we prevent accessing the page from the launcher
    // TODO: if in the same tab, we leave the commit page and return again from other US, page state will remain until page is refreshed,
    // connectedCallback is not triggered and inputs maintain their previous values.
    // Investigate root cause of this and consider manually resetting all input values
    async connectedCallback() {
        this.showSpinner = true;
        const safeReCreateFeatureBranchAvailable = handleAsyncError(this._reCreateFeatureBranchAvailable, {});
        this.reCreateFeatureBranchAvailable = await safeReCreateFeatureBranchAvailable(this, {});
        this.showSpinner = false;
        this._handleSubscribe();
    }

    // TEMPLATE

    handleInputChange(event) {
        this[event.target.name] = event.target.value;
    }

    handleCheckBoxChange(event) {
        this[event.target.name] = event.target.checked;
    }

    // PRIVATE

    _handleSubscribe() {
        subscribe(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, (event) => {
            if (event != null && event.type === 'request') {
                const payload = {
                    type: 'commitInformation',
                    commitMessage: this.commitMessage,
                    reCreateFeatureBranch: this.reCreate,
                    baseBranch: this.baseBranch
                };
                publish(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, payload);
            }
        });
    }

    /**
     * Wrapper function with self (although unused) parameter so it can be used by handlerAsyncError
     */
    _reCreateFeatureBranchAvailable(self, fields) {
        return reCreateFeatureBranchAvailable(fields);
    }
}