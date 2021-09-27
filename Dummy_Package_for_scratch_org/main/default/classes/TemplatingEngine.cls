public inherited sharing class TemplatingEngine {
    private static final Pattern NAME_PATTERN = Pattern.compile('[a-zA-Z_][a-zA-Z0-9_]*');

    private List<Parameter> parameters;
    private List<DynamicExpression> parsers;

    // CONSTRUCTOR

    public TemplatingEngine(String contextId, List<Parameter> parameters) {
        this.parameters = parameters != null ? parameters : new List<Parameter>();

        contextId = String.isBlank(contextId) ? null : contextId;

        // Note: Order of parsers matter
        parsers = new List<DynamicExpression>{
            new UserExpression(contextId),
            new StepExpression(contextId),
            new CredentialExpression(contextId),
            new SystemExpression(contextId),
            new RepositoryExpression(contextId),
            new SObjectExpression(contextId),
            new InvalidExpression()
        };

        prepare();
    }

    // PUBLIC

    public List<Parameter> parse() {
        for (Parameter parameter : parameters) {
            parameter.value = String.isNotBlank(parameter.value) ? parameter.value.trim() : parameter.value;
            getParser(parameter)?.parse(parameter);
            assert(truthy(parameter.required) && String.isBlank(parameter.value), Label.RequiredFieldMissing + parameter.name);
        }

        return parameters;
    }

    // PRIVATE

    private void prepare() {
        for (Parameter parameter : parameters) {
            Matcher nameMatcher = NAME_PATTERN.matcher(parameter.name);
            assert(!nameMatcher.matches(), String.format(Label.InvalidNameformat, new List<String>{ parameter.name }));

            parameter.value = String.isNotBlank(parameter.value)
                ? parameter.value
                : (String.isNotBlank(parameter.defaultValue) ? parameter.defaultValue : '');
            getParser(parameter)?.add(parameter);
        }

        for (DynamicExpression parser : parsers) {
            if (parser.hasParameters()) {
                parser.prepare();
            }
        }
    }

    private DynamicExpression getParser(Parameter parameter) {
        DynamicExpression result = null;

        for (DynamicExpression parser : parsers) {
            if (parser.matches(parameter)) {
                result = parser;
                break;
            }
        }

        return result;
    }

    private void assert(Boolean unExpected, String message) {
        if (unExpected) {
            throw new CopadoFunctionException(message);
        }
    }

    private Boolean truthy(Boolean expression) {
        return expression != null && expression;
    }
}