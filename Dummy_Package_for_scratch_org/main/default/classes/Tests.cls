public with sharing class Tests extends fflib_SObjectDomain {
    // CTOR

    public Tests(List<Test__c> records) {
        super(records);
    }

    // PUBLIC

    public override void onBeforeInsert() {
        updateHierarchy((List<Test__c>) records);
    }

    public override void onBeforeUpdate(Map<Id, SObject> oldTests) {
        List<Test__c> filteredTests = filterByNewHierarchy((List<Test__c>) records, (Map<Id, Test__c>) oldTests);
        List<Test__c> refinedTests = resetOnNewHierarchy((List<Test__c>) filteredTests, (Map<Id, Test__c>) oldTests);
        updateHierarchy((List<Test__c>) refinedTests);
    }

    // PRIVATE

    private List<Test__c> filterByNewHierarchy(List<Test__c> newTests, Map<Id, Test__c> oldTests) {
        List<Test__c> result = new List<Test__c>();

        for (Test__c newTest : newTests) {
            Test__c oldTest = oldTests.get(newTest.Id);

            if (isHierarchyChanged(newTest, oldTest)) {
                result.add(newTest);
            }
        }

        return result;
    }

    private Boolean isHierarchyChanged(Test__c newTest, Test__c oldTest) {
        return (newTest.User_Story__c != oldTest.User_Story__c) ||
            (newTest.Feature__c != oldTest.Feature__c) ||
            (newTest.Application__c != oldTest.Application__c);
    }

    private List<Test__c> resetOnNewHierarchy(List<Test__c> newTests, Map<Id, Test__c> oldTests) {
        List<Test__c> result = new List<Test__c>();

        for (Test__c newTest : newTests) {
            Test__c oldTest = oldTests.get(newTest.Id);

            if (newTest.User_Story__c == oldTest.User_Story__c) {
                if (newTest.Feature__c != oldTest.Feature__c && newTest.Feature__c != null) {
                    newTest.User_Story__c = null;
                    newTest.Application__c = null;
                } else if (newTest.Application__c != oldTest.Application__c && newTest.Application__c != null) {
                    newTest.User_Story__c = null;
                    newTest.Feature__c = null;
                }
            }

            result.add(newTest);
        }

        return result;
    }

    private void updateHierarchy(List<Test__c> tests) {
        Map<Test__c, User_Story__c> completeUserStoryByTest = getCompleteUserStoryByTest(tests);
        Map<Test__c, Application_Feature__c> completeFeatureByTest = getCompleteFeatureByTest(tests);

        for (Test__c test : tests) {
            if (test.User_Story__c != null) {
                User_Story__c relatedUserStory = completeUserStoryByTest.get(test);

                test.Feature__c = relatedUserStory.US_Feature__c;
                test.Application__c = relatedUserStory.US_Feature__r.Application__c;
            }

            if (test.User_Story__c == null && test.Feature__c != null) {
                test.Application__c = completeFeatureByTest.get(test).Application__c;
            }
        }
    }

    private Map<Test__c, User_Story__c> getCompleteUserStoryByTest(List<Test__c> tests) {
        Map<Test__c, User_Story__c> result = new Map<Test__c, User_Story__c>();

        List<User_Story__c> stories = new UserStoriesSelector().byIds(getUserStoriesFrom(tests));

        for (Test__c test : tests) {
            for (User_Story__c userStory : stories) {
                if (test.User_Story__c == userStory.Id) {
                    result.put(test, userStory);
                }
            }
        }

        return result;
    }

    private Set<Id> getUserStoriesFrom(List<Test__c> tests) {
        Set<Id> result = new Set<Id>();

        for (Test__c test : tests) {
            if (test.User_Story__c != null) {
                result.add(test.User_Story__c);
            }
        }

        return result;
    }

    private Map<Test__c, Application_Feature__c> getCompleteFeatureByTest(List<Test__c> tests) {
        Map<Test__c, Application_Feature__c> result = new Map<Test__c, Application_Feature__c>();

        List<Application_Feature__c> features = new FeaturesSelector().byIds(getFeaturesFrom(tests));

        for (Test__c test : tests) {
            for (Application_Feature__c feature : features) {
                if (test.Feature__c == feature.Id) {
                    result.put(test, feature);
                }
            }
        }

        return result;
    }

    private Set<Id> getFeaturesFrom(List<Test__c> tests) {
        Set<Id> result = new Set<Id>();

        for (Test__c test : tests) {
            if (test.Feature__c != null) {
                result.add(test.Feature__c);
            }
        }

        return result;
    }

    // INNER

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> records) {
            return new Tests(records);
        }
    }
}