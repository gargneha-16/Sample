import { LightningElement, api, wire } from 'lwc';

import { reduceErrors } from 'c/copadocoreUtils';
import { publish, MessageContext } from 'lightning/messageService';

import removeSelectedPromotedUserStories from '@salesforce/apex/PromotedUserStoriesDatatableController.removeSelectedPromotedUserStories';

import COPADO_ALERT_CHANNEL from '@salesforce/messageChannel/CopadoAlert__c';

import Remove_Promoted_User_Stories_Confirmation from '@salesforce/label/c.Remove_Promoted_User_Stories_Confirmation';
import Error_while_removing_promoted_user_stories from '@salesforce/label/c.Error_while_removing_promoted_user_stories';
import Promoted_user_stories_removed_successfully from '@salesforce/label/c.Promoted_user_stories_removed_successfully';
import Cancel from '@salesforce/label/c.Cancel';
import Confirm from '@salesforce/label/c.Confirm';
import Remove_Promoted_User_Stories from '@salesforce/label/c.Remove_Promoted_User_Stories';

/*eslint no-extend-native: ["error", { "exceptions": ["String"] }]*/
String.prototype.format = function() {
    var s = this,
        i = arguments.length;

    while (i--) {
        s = s.replace(new RegExp('\\{' + i + '\\}', 'gm'), arguments[i]);
    }
    return s;
};

export default class PromotedUserStoriesRemovalModal extends LightningElement {
    @api promotedUserStoryIds;

    communicationId = 'promotionRecordPageAlerts';

    label = {
        Cancel,
        Confirm,
        Remove_Promoted_User_Stories
    };

    @wire(MessageContext)
    messageContext;

    get body() {
        return Remove_Promoted_User_Stories_Confirmation.format(this.promotedUserStoryIds?.length);
    }

    @api show() {
        this.template.querySelector('c-copadocore-modal').show();
    }

    @api hide() {
        this.template.querySelector('c-copadocore-modal').hide();
    }

    handleCancel() {
        this.hide();
    }

    messageAlert(message, variant, dismissible) {
        const payload = {
            variant,
            message,
            dismissible,
            communicationId: this.communicationId
        };
        publish(this.messageContext, COPADO_ALERT_CHANNEL, payload);
    }

    async handleConfirm() {
        this.hide();

        try {
            const promotedUserStoryIds = this.promotedUserStoryIds;
            await removeSelectedPromotedUserStories({ promotedUserStoryIds });
            this.messageAlert(Promoted_user_stories_removed_successfully, 'success', true);
        } catch (error) {
            this.messageAlert(Error_while_removing_promoted_user_stories + ' ' + reduceErrors(error), 'error', true);
        }

        this.dispatchEvent(new CustomEvent('promoteduserstoriesremoved'));
    }
}