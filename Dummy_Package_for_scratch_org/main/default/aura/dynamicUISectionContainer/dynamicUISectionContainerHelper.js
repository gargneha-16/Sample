({
    publishPlatformRequest: function (component) {
        const uiSectionId = component.get('v.locationId');
        const payload = {
            type: 'dynamicRendering',
            name: uiSectionId
        };
        component.find('messageChannel').publish(payload);
    },

    handleMessageSubscription: function (component, message) {
        const uiSectionId = component.get('v.locationId');
        const platform = message.getParam('platform');
        if (message != null && message.getParam('type') === uiSectionId && platform != null) {
            this.getComponentToRender(component, platform, uiSectionId);
        }
    },

    getComponentToRender: function (component, platform, uiSectionId) {
        this.callApex(component, 'c.fetchUISection', { platform, uiSectionId }).then(
            $A.getCallback((uiSection) => {
                this.renderDynamicComponent(component, uiSection);
            })
        );
    },

    renderDynamicComponent: function (component, uiSection) {
        const componentName = uiSection.Component__c || uiSection.copado__Component__c;
        $A.createComponent(componentName, {}, (createdComponent, status, errorMessage) => {
            switch (status) {
                case 'SUCCESS':
                    const body = component.get('v.body');
                    body.push(createdComponent);
                    component.set('v.body', body);
                    break;
                case 'ERROR':
                    console.error('Error: ' + errorMessage);
                    break;
                default:
            }
        });
    }
});