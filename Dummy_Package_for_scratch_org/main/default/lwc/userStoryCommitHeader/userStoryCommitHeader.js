import { LightningElement, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { MessageContext, publish, subscribe } from 'lightning/messageService';

import { namespace, handleAsyncError, reduceErrors } from 'c/copadocoreUtils';
import { showToastError } from 'c/copadocoreToastNotification';

import commitChanges from '@salesforce/apex/UserStoryCommitCtrl.commitChanges';

import COMMIT_PAGE_COMMUNICATION_CHANNEL from '@salesforce/messageChannel/CommitPageCommunication__c';

import { label, schema } from './constants';

export default class UserStoryCommitHeader extends NavigationMixin(LightningElement) {
    label = label;

    showSpinner;

    // These variables, although "private", do not start with '_'
    recordId;
    commitInformation;
    changes;
    selectedMetadata;

    _platform;
    _componentsToRender = new Set();

    validEntryPoint = false;

    get _isRequestReady() {
        return this.commitInformation && this.changes;
    }

    @wire(MessageContext)
    _context;

    @wire(CurrentPageReference)
    getParameters(pageReference) {
        // Note: workaround in case we have cached data in the page, this will force rerender of dynamic components
        if (this.recordId) {
            location.reload();
        }
        if (pageReference && pageReference.state) {
            const parameterName = `${namespace || 'c__'}recordId`;
            this.recordId = pageReference.state[parameterName];

            this.validEntryPoint = !!this.recordId;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [schema.PLATFORM_FIELD] })
    wiredRecord({ error, data }) {
        if (data) {
            this._platform = getFieldValue(data, schema.PLATFORM_FIELD);
            if (this.validEntryPoint && this._platform) {
                this._renderComponentsQueue();
            }
        } else if (error) {
            const errorMessage = reduceErrors(error);
            showToastError(this, { message: errorMessage });
        }
    }

    connectedCallback() {
        this._handleSubscribe();
    }

    // TEMPLATE

    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: schema.USER_STORY_OBJECT.objectApiName,
                actionName: 'view'
            }
        });
    }

    handleCommit() {
        this.showSpinner = true;
        const payload = {
            type: 'request'
        };
        publish(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, payload);
    }

    // PRIVATE

    _handleSubscribe() {
        subscribe(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, (event) => {
            if (event != null) {
                if (event.type === 'commitInformation' || event.type === 'changes') {
                    this[event.type] = event;
                    this._commit();
                } else if (event.type === 'dynamicRendering') {
                    const uiSectionId = event.name;
                    this._componentsToRender.add(uiSectionId);
                    if (this.validEntryPoint && this._platform) {
                        this._renderComponentsQueue();
                    }
                }
            }
        });
    }

    async _commit() {
        if (this._isRequestReady) {
            const request = {
                userStoryId: this.recordId,
                changes: this.changes.value,
                reCreateFeatureBranch: this.commitInformation.reCreateFeatureBranch || false,
                executeCommit: true,
                baseBranch: this.commitInformation.baseBranch,
                message: this.commitInformation.commitMessage
            };

            const safeCommitChanges = handleAsyncError(this._commitChanges, {});
            const result = await safeCommitChanges(this, { request });
            if (result) {
                this._navigateToUserStoryCommitRecord(result.UserStoryCommit__c);
            }
            this.showSpinner = false;
        }
    }

    _navigateToUserStoryCommitRecord(userStoryCommitId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: userStoryCommitId,
                objectApiName: schema.USER_STORY_COMMIT_OBJECT.objectApiName,
                actionName: 'view'
            }
        });
    }

    /**
     * Wrapper function with self (although unused) parameter so it can be used by handlerAsyncError
     */
    _commitChanges(self, fields) {
        return commitChanges(fields);
    }

    _renderComponentsQueue() {
        this._componentsToRender.forEach((uiSectionId) => {
            this._requestComponentToRender(uiSectionId, this._platform);
            this._componentsToRender.delete(uiSectionId);
        });
    }

    _requestComponentToRender(uiSectionId, platform) {
        const payload = {
            type: uiSectionId,
            platform: platform
        };
        publish(this._context, COMMIT_PAGE_COMMUNICATION_CHANNEL, payload);
    }
}