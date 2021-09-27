public with sharing class InvalidExpression extends DynamicExpression {
    private static final Pattern INVALID_PATTERN = Pattern.compile('\\{\\$?[a-zA-Z_][a-zA-Z0-9_]*\\.[a-zA-Z_][a-zA-Z0-9_]*(\\.[a-zA-Z_][a-zA-Z0-9_]*)?\\}');

    private Map<Id, SObject> recordsById;


    // CONSTRUCTOR

    public InvalidExpression() {}


    // PUBLIC

    public override Boolean matches(Parameter parameter) {
        Matcher matcher = INVALID_PATTERN.matcher(parameter.value);

        return matcher.matches();
    }


    public override void parse(Parameter parameter) {
        if(matches(parameter)) {
            throw new CopadoFunctionException(Label.InValidExpression + parameter.value);
        }
    }
}