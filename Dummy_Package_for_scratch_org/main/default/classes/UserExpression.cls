public inherited sharing class UserExpression extends DynamicExpression {
    private static final Pattern USER_PATTERN = Pattern.compile('(?i)\\{\\$?(User).([A-Za-z0-9_]+)\\}');

    private User loggedInUser;

    // CONSTRUCTOR

    public UserExpression(String contextId) {
        this.contextId = contextId;
    }

    // PUBLIC

    public override void prepare() {
        loggedInUser = loggedInUser();
    }

    public override Boolean matches(Parameter parameter) {
        Matcher userMatcher = USER_PATTERN.matcher(parameter.value);

        return userMatcher.matches();
    }

    public override void parse(Parameter parameter) {
        Matcher userMatcher = USER_PATTERN.matcher(parameter.value);

        if (userMatcher.matches()) {
            String propertyName = userMatcher.group(2);
            parameter.value = (String) loggedInUser.get(propertyName);
        }
    }

    // PRIVATE

    @SuppressWarnings('PMD.UnusedLocalVariable')
    private User loggedInUser() {
        User result = null;

        List<String> userFields = userFields();

        if (!userFields.isEmpty()) {
            Id userId = UserInfo.getUserId();
            String query = 'SELECT ' + String.join(userFields, ', ') + ' FROM User WHERE Id = :userId WITH SECURITY_ENFORCED';
            result = Database.query(String.escapeSingleQuotes(query));
        }

        return result;
    }

    private List<String> userFields() {
        Set<String> result = new Set<String>();

        for (Parameter parameter : parameters) {
            String value = parameter.value;

            Matcher userMatcher = USER_PATTERN.matcher(value);

            if (userMatcher.matches()) {
                result.add(userMatcher.group(2));
            }
        }

        return new List<String>(result);
    }
}