trigger OnJobStepComplete on Event__e (after insert) {
    new OnJobStepComplete(Trigger.new).execute();
}