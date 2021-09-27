import RunTests from '@salesforce/label/c.RunTests';
import TestType from '@salesforce/label/c.TestType';
import Tool from '@salesforce/label/c.Tool';
import Result from '@salesforce/label/c.Result';
import Status from '@salesforce/label/c.STATUS';
import TestName from '@salesforce/label/c.TEST_NAME';
import RunDate from '@salesforce/label/c.RUN_DATE';
import Search from '@salesforce/label/c.Search';

import userStory from '@salesforce/schema/User_Story__c';
import feature from '@salesforce/schema/Application_Feature__c';
import application from '@salesforce/schema/Application__c';

export const label = {
    TestType,
    TestName,
    RunDate,
    RunTests,
    Tool,
    Result,
    Status,
    Search
};

export const schema = {
    userStory,
    feature,
    application
};