({
    init : function(component) {
        const getNamespace = component.get("c.getNamespace");

        getNamespace.setCallback(this, function(response) {
            const state = response.getState();
            
            if(state === "SUCCESS") {
                const namespace = response.getReturnValue();
                component.set("v.namespace", namespace);
                this.initStep(component);
            } else if(state === "ERROR") {
                this.showErrors(response.getError(), $A.get("$Label.c.Error_Retrieving_Namespace"));
            }
        });

        $A.enqueueAction(getNamespace);
    },
    
    initStep : function(component) {
        const recordId = component.get("v.recordId");
        const namespace = component.get("v.namespace");
        
        if(recordId) {
            const getStep = component.get("c.getStep");
            getStep.setParams({ stepId : component.get("v.recordId") });
            getStep.setCallback(this, function(response) {
                const state = response.getState();
                
                if(state === "SUCCESS") {
                    const step = response.getReturnValue();
                    
                    component.set("v.step", step);
                    component.set("v.stepName", step.Name);
                    component.set("v.stepCustomType", step[namespace + "CustomType__c"]);
                    component.set("v.configJson", step[namespace + "ConfigJson__c"]);
                } else if(state === "ERROR") {
                    this.showErrors(response.getError(), $A.get("$Label.c.Error_Retrieving_Step"));
                }

                this.initStepOptions(component);
            });

            $A.enqueueAction(getStep);

            component.set("v.modalTitle", $A.get("$Label.c.Edit_Step"));
        } else {
            this.initStepOptions(component);
            component.set("v.modalTitle", $A.get("$Label.c.Add_New_Step"));
        }
    },

    initStepOptions : function(component) {
        const getStepOptions = component.get("c.getStepOptions");

        getStepOptions.setCallback(this, function(response) {
            const state = response.getState();
            
            if(state === "SUCCESS") {
                let options = [];
                let componentsByType = new Map();
                const result = response.getReturnValue();
                
                result.forEach(option => {
                    options.push({ label: option.label, value: option.type });
                    componentsByType.set(option.type, option.component);
                });
                
                component.set("v.stepOptions", options);
                component.set("v.componentsByType", componentsByType);

                let type = component.get("v.stepCustomType");
                if(type) {
                    this.switchView(component);
                }
            } else if(state === "ERROR") {
                this.showErrors(response.getError(), $A.get("$Label.c.Error_Loading_Step_Options"));
            }
        });

        $A.enqueueAction(getStepOptions);
    },
    
    switchView : function(component) {
        const componentsByType = component.get("v.componentsByType");
        const selectedComponent = componentsByType.get(component.get("v.stepCustomType"));

        $A.createComponent(
            selectedComponent, 
            {
                "stepId": component.get("v.recordId"),
                "configJson": component.get("v.configJson")
            }, 
            (stepComponent, status, errorMessage) => {
                if(status === "SUCCESS") {
                    component.set("v.componentBody", stepComponent);
                } else if(status === "ERROR") {
                    console.error('Error', errorMessage.toString());
                    component.set("v.componentBody", undefined);
                }
            }
        );
    },

    saveStep : function(component) {
        const saveStep = component.get("c.saveStep");
        saveStep.setParams({ record : this.step(component) });
        saveStep.setCallback(this, function(response) {
            const state = response.getState();
            
            if(state === "SUCCESS") {
                this.showToast("Success", "success", "Step successfully saved.");
                $A.get('e.force:refreshView').fire();
                this.navigateToRecord(component);
                this.delayedRefresh();
            } else if(state === "ERROR") {
                this.showErrors(response.getError(), $A.get("$Label.c.Error_Saving_Step"));
            }
        });

        $A.enqueueAction(saveStep);
    },

    step : function(component) {
        const recordId = component.get("v.recordId");
        const namespace = component.get("v.namespace");
        let result = {
            Id : recordId,
            Name : component.get("v.stepName"),
            [namespace + "ConfigJson__c"] : JSON.stringify(component.get("v.configJson")),
            [namespace + "Type__c"] : component.get("v.stepType"),
            [namespace + "CustomType__c"] : component.get("v.stepCustomType")
        };

        if(!recordId) {
            const parent = this.parentId(component);
            result[parent.objectApiName] = parent.Id;
        }
        
        return result;
    },

    pageReference : function(component) {
        const pageRef = component.get("v.pageReference");
        const state = pageRef.state;
        let base64Context = state.inContextOfRef;

        if(base64Context.startsWith("1\.")) {
            base64Context = base64Context.substring(2);
        }

        return JSON.parse(window.atob(base64Context));
    },

    parentId : function(component) {
        const addressableContext = this.pageReference(component);

        return {
            objectApiName : addressableContext.attributes.objectApiName,
            Id : addressableContext.attributes.recordId
        };
    },

    showErrors : function(errors, label) {
        if(errors && errors[0] && errors[0].message) {
            this.showToast("Error", "error", label + errors[0].message);
        } else {
            this.showToast("Error", "error", label + $A.get("$Label.c.Unexpected_Error_Occurred"));
        }
    },

    showToast : function(title, type, message) {
        $A.get("e.force:showToast").fire({ title, type, message });
    },

    isValidConfig : function(component, childComponent) {
        let result = null;

        const stepType = component.get("v.stepType");
        const config = component.get("v.configJson");
        const customType = component.get("v.stepCustomType");
        const name = component.find("step-name").get("v.value");
        const childFormValid = childComponent.getAutoFormValidation ? childComponent.getAutoFormValidation() : true;

        if(childFormValid) {
            if (stepType === "Function" && !config.functionName) {
                result = $A.get("$Label.c.RequiredFieldMissing") + " Function Name";
            } else if(stepType === "Flow" && !config.flowName) {
                result = $A.get("$Label.c.RequiredFieldMissing") + " Flow Name";
            } else if(stepType === "Manual" && !this.hasOwner(config)) {
                result = $A.get("$Label.c.RequiredFieldMissing") + " Manual Task Owner";
            } else if(!(name && name.trim() && customType)) {
                result = $A.get("$Label.c.FILL_REQUIRED_FIELDS");
            }

            if(result) {
                this.showToast("Error", "error", result);
            }
        }


        return (!result && childFormValid);
    },

    hasOwner: function(config) {
        const parameters = config.parameters || [];

        return parameters.some((parameter) => parameter.name === 'ownerId' && parameter.value);
    },

    navigateToRecord : function(component) {
        const navigation = component.find("navService");
        const pageRef = this.pageReference(component);

        navigation.navigate(pageRef, true);
    },

    delayedRefresh : function(){
        window.setTimeout(
            $A.getCallback(function(){
                $A.get('e.force:refreshView').fire();
            }
        ), 500);
    }
})