({
    doInit : function(component, event, helper) {
        helper.init(component);
    },

    switchView : function(component, event, helper) {
        helper.switchView(component);
    },

    handleSave : function(component, event, helper) {
        const childComponent = component.get("v.componentBody") || {};
        if(childComponent.getConfig) {
            const config = childComponent.getConfig();

            if(config) {
                component.set("v.stepType", config.type);
                component.set("v.configJson", config.configJson);
            }
        }

        if(helper.isValidConfig(component, childComponent)) {
            helper.saveStep(component);
        }
    },

    handleCancel : function() {
        window.history.back();
        $A.get('e.force:refreshView').fire();
    }
})