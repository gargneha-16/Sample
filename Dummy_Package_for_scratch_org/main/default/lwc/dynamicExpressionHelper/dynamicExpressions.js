export default {
    "options": [
        {
            "label": "Record",
            "value": "Context",
            "options": [
                {
                    "label": "Field API name",
                    "value": "",
                    "isFieldSelector": true,
                    "helpText": "Enter the field API name"
                },
                {
                    "label": "Repository Credential",
                    "value": "Repository.Credential"
                },
                {
                    "label": "Environment SessionId",
                    "value": "Credential.SessionId"
                },
                {
                    "label": "Environment Endpoint",
                    "value": "Credential.Endpoint"
                }
            ]
        },
        {
            "label": "Source Environment",
            "value": "Source",
            "options": [
                {
                    "label": "Field API name",
                    "value": "",
                    "isFieldSelector": true,
                    "helpText": "Enter the field API name"
                },
                {
                    "label": "System Property",
                    "value": "Property",
                    "isFieldSelector": true,
                    "helpText": "Enter API name of System property"
                },
                {
                    "label": "SessionId",
                    "value": "Credential.SessionId"
                },
                {
                    "label": "Endpoint",
                    "value": "Credential.Endpoint"
                }
            ]
        },
        {
            "label": "Destination Environment",
            "value": "Destination",
            "options": [
                {
                    "label": "Field API name",
                    "value": "",
                    "isFieldSelector": true,
                    "helpText": "Enter the field API name"
                },
                {
                    "label": "System Property",
                    "value": "Property",
                    "isFieldSelector": true,
                    "helpText": "Enter API name of System Property"
                },
                {
                    "label": "SessionId",
                    "value": "Credential.SessionId"
                },
                {
                    "label": "Endpoint",
                    "value": "Credential.Endpoint"
                }
            ]
        },
        {
            "label": "Pipeline",
            "value": "Pipeline",
            "options": [
                {
                    "label": "Field API name",
                    "value": "",
                    "isFieldSelector": true,
                    "helpText": "Enter the field API name"
                },
                {
                    "label": "System Property",
                    "value": "Property",
                    "isFieldSelector": true,
                    "helpText": "Enter API name of System Property"
                }
            ]
        },
        {
            "label": "Job",
            "value": "Job",
            "options": [
                {
                    "label": "Step",
                    "value": "Step",
                    "isFieldSelector": true,
                    "helpText": "Enter the key of the result data json from the {step name}. Example: 'Step Name.datajson.key' or 'Step Name.fieldName'"
                },
                {
                    "label": "First Step",
                    "value": "FirstStep",
                    "options": [
                        {
                            "label": "Field API name",
                            "value": "",
                            "isFieldSelector": true,
                            "helpText": "Enter the field API name"
                        },
                        {
                            "label": "Result Data Json",
                            "value": "JSONResult",
                            "isFieldSelector": true,
                            "helpText": "Enter key of Result data json from first step"
                        }
                    ]
                },
                {
                    "label": "Prev Step",
                    "value": "PrevStep",
                    "options": [
                        {
                            "label": "Field API name",
                            "value": "",
                            "isFieldSelector": true,
                            "helpText": "Enter the field API name"
                        },
                        {
                            "label": "Result Data Json",
                            "value": "JSONResult",
                            "isFieldSelector": true,
                            "helpText": "Enter key of Result data json from previous step"
                        }
                    ]
                },
                {
                    "label": "Next Step",
                    "value": "NextStep",
                    "options": [
                        {
                            "label": "Field API name",
                            "value": "",
                            "isFieldSelector": true,
                            "helpText": "Enter the field API name"
                        },
                        {
                            "label": "Result Data Json",
                            "value": "JSONResult",
                            "isFieldSelector": true,
                            "helpText": "Enter key of Result data json from next step"
                        }
                    ]
                },
                {
                    "label": "Last Step",
                    "value": "LastStep",
                    "options": [
                        {
                            "label": "Field API name",
                            "value": "",
                            "isFieldSelector": true,
                            "helpText": "Enter the field API name"
                        },
                        {
                            "label": "Result Data Json",
                            "value": "JSONResult",
                            "isFieldSelector": true,
                            "helpText": "Enter key of Result data json from last step"
                        }
                    ]
                },
                {
                    "label": "Execution Parent",
                    "value": "ExecutionParent",
                    "isFieldSelector": true,
                    "helpText": "Enter field API name of parent record"
                }
            ]
        },
        {
            "label": "User",
            "value": "User",
            "options": [
                {
                    "label": "Field API name",
                    "value": "",
                    "isFieldSelector": true,
                    "helpText": "Enter the field API name"
                },
                {
                    "label": "System Property",
                    "value": "Property",
                    "isFieldSelector": true,
                    "helpText": "Enter API name of System property"
                }
            ]
        }
    ]
}