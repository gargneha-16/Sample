import LOADING from '@salesforce/label/c.LOADING';
import USER_STORY_COMMIT from '@salesforce/label/c.User_Story_Commit';
import BACK_TO_USER_STORY from '@salesforce/label/c.BackToUserStory';
import COMMIT_NOW from '@salesforce/label/c.COMMIT_NOW';
import COMMIT_CHANGES_PAGE_NOT_ACCESSIBLE_TITLE from '@salesforce/label/c.CommitChangesPageNotAccessibleTitle';
import COMMIT_CHANGES_PAGE_NOT_ACCESSIBLE_BODY from '@salesforce/label/c.CommitChangesPageNotAccessibleBody';

import USER_STORY_OBJECT from '@salesforce/schema/User_Story__c';
import USER_STORY_COMMIT_OBJECT from '@salesforce/schema/User_Story_Commit__c';
import PLATFORM_FIELD from '@salesforce/schema/User_Story__c.Platform__c';

export const label = {
    LOADING,
    USER_STORY_COMMIT,
    BACK_TO_USER_STORY,
    COMMIT_NOW,
    COMMIT_CHANGES_PAGE_NOT_ACCESSIBLE_TITLE,
    COMMIT_CHANGES_PAGE_NOT_ACCESSIBLE_BODY
};

export const schema = {
    USER_STORY_OBJECT,
    USER_STORY_COMMIT_OBJECT,
    PLATFORM_FIELD
};