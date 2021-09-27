public with sharing class RunTestsInExtension {
    private List<Test__c> tests;

    // CTOR

    public RunTestsInExtension(List<Test__c> tests) {
        this.tests = tests;
        validateTests(tests);
    }

    // PUBLIC

    public List<Result__c> execute() {
        try {
            Map<String, List<Test__c>> testsByTool = getTestsByTool(tests);
            return delegateToExtensionsLogic(testsByTool);
        } catch (Exception e) {
            throw new ApplicationException(Label.NoTestExtensionConfigured);
        }
    }

    public List<Result__c> executeAsAutomation(Id deploymentJobId) {
        List<Result__c> results = new List<Result__c>();

        try {
            Map<String, List<Test__c>> testsByTool = getTestsByTool(tests);
            results = delegateToExtensionsLogic(testsByTool, deploymentJobId);
        } catch (Exception e) {
            updateFailedDeploymentJob(deploymentJobId, Label.NoTestExtensionConfigured);
        }

        return results;
    }

    // PRIVATE

    private void updateFailedDeploymentJob(Id deploymentJobId, String errorMessage) {
        Deployment_Job__c job = new Deployment_Job__c(Id = deploymentJobId, Status__c = 'Failed');
        Utilities.Secure_DML(job, Utilities.DML_Action.UPD, Schema.SObjectType.Deployment_Job__c);

        JobAttachmentDetails attachmentDetail = new JobAttachmentDetails();
        attachmentDetail.m = errorMessage;
        attachmentDetail.l = 'INFO';
        attachmentDetail.t = '';

        Attachment jobTaskAttachment = new Attachment();
        jobTaskAttachment.Name = deploymentJobId + '.json';
        jobTaskAttachment.ParentId = deploymentJobId;
        jobTaskAttachment.Body = Blob.valueOf(JSON.serialize(new List<JobAttachmentDetails>{ attachmentDetail }));

        Utilities.Secure_DML(jobTaskAttachment, Utilities.DML_Action.INS, Schema.SObjectType.Attachment);
    }

    private void validateTests(List<Test__c> tests) {
        if (tests.isEmpty()) {
            throw new ApplicationException(Label.NoTestsToRun);
        }
    }

    private List<Result__c> delegateToExtensionsLogic(Map<String, List<Test__c>> testsByTool) {
        List<Result__c> results = new List<Result__c>();

        Map<String, String> extensionRunnerClassByTool = getExtensionRunnerClassesByTools();

        for (String testTool : testsByTool.keySet()) {
            String extensionRunnerClass = extensionRunnerClassByTool.get(testTool);
            Callable extension = (Callable) Type.forName(extensionRunnerClass).newInstance();

            results.addAll((List<Result__c>) extension.call(Label.ExecuteTestsAction, shapeForCallable(testsByTool.get(testTool))));
        }

        return results;
    }

    private List<Result__c> delegateToExtensionsLogic(Map<String, List<Test__c>> testsByTool, Id deploymentJobId) {
        List<Result__c> results = new List<Result__c>();

        Map<String, String> extensionRunnerClassByTool = getExtensionRunnerClassesByTools();

        for (String testTool : testsByTool.keySet()) {
            String extensionRunnerClass = extensionRunnerClassByTool.get(testTool);
            Callable extension = (Callable) Type.forName(extensionRunnerClass).newInstance();

            results.addAll(
                (List<Result__c>) extension.call(
                    Label.ExecuteTestsAsAutomationAction,
                    shapeForCallableAsAutomation(testsByTool.get(testTool), deploymentJobId)
                )
            );
        }

        return results;
    }

    private Map<String, Object> shapeForCallable(List<Test__c> tests) {
        Map<String, Object> result = new Map<String, Object>();

        for (Test__c test : tests) {
            result.put(test.Id, test);
        }

        return result;
    }

    private Map<String, Object> shapeForCallableAsAutomation(List<Test__c> tests, Id deploymentJobId) {
        Map<String, Object> result = new Map<String, Object>();

        for (Test__c test : tests) {
            result.put(deploymentJobId, test);
        }

        return result;
    }

    private Map<String, List<Test__c>> getTestsByTool(List<Test__c> tests) {
        Map<String, List<Test__c>> result = new Map<String, List<Test__c>>();

        for (Test__c test : tests) {
            List<Test__c> testsForTool = result.containsKey(test.Tool__c) ? result.get(test.Tool__c) : new List<Test__c>();

            testsForTool.add(test);
            result.put(test.Tool__c, testsForTool);
        }

        return result;
    }

    private Map<String, String> getExtensionRunnerClassesByTools() {
        Map<String, String> result = new Map<String, String>();

        List<TestType__mdt> testTypes = new TestTypesSelector().getAll();
        for (TestType__mdt testType : testTypes) {
            String extensionRunnerClass = '';
            if (String.isBlank(testType.Namespace__c)) {
                extensionRunnerClass = testType.ExecuteVia__c;
            } else {
                extensionRunnerClass = testType.Namespace__c + '.' + testType.ExecuteVia__c;
            }

            result.put(testType.Tool__c, extensionRunnerClass);
        }

        return result;
    }

    private class JobAttachmentDetails {
        public String m { get; set; }
        public String l { get; set; }
        public String t { get; set; }
    }
}