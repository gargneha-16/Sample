trigger MCResults on MC_Result__e(after insert) {
  fflib_SObjectDomain.triggerHandler(MCResults.class);
}