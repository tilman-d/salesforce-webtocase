/**
 * ErrorLogger - Utility class for logging errors to Error_Log__c
 * Used for debugging issues in the public form submission process
 */
public class ErrorLogger {

    /**
     * Log an error message with stack trace
     * @param message Error message
     * @param stackTrace Apex stack trace
     * @param formId ID of the form that had the error
     */
    private static final Integer MAX_MESSAGE_LENGTH = 32768;
    private static final Integer MAX_STACK_TRACE_LENGTH = 32768;

    // Test-visible flag to simulate CRUD denial in tests
    @TestVisible private static Boolean testDenyCrud = false;

    public static void log(String message, String stackTrace, String formId) {
        try {
            // CRUD check: fail silently to avoid masking original errors
            if (Test.isRunningTest() && testDenyCrud) {
                System.debug(LoggingLevel.ERROR, 'ErrorLogger: CRUD denied (test override)');
                return;
            }
            if (!Schema.sObjectType.Error_Log__c.isCreateable()) {
                System.debug(LoggingLevel.ERROR, 'ErrorLogger: No create access to Error_Log__c');
                return;
            }

            // Truncate to field limits
            String truncatedMessage = message != null && message.length() > MAX_MESSAGE_LENGTH
                ? message.substring(0, MAX_MESSAGE_LENGTH)
                : message;
            String truncatedStack = stackTrace != null && stackTrace.length() > MAX_STACK_TRACE_LENGTH
                ? stackTrace.substring(0, MAX_STACK_TRACE_LENGTH)
                : stackTrace;

            Error_Log__c errorLog = new Error_Log__c(
                Timestamp__c = DateTime.now(),
                Error_Message__c = truncatedMessage,
                Stack_Trace__c = truncatedStack,
                Form_Id__c = formId
            );
            insert errorLog;
        } catch (Exception e) {
            // Don't let error logging fail silently break the app
            System.debug(LoggingLevel.ERROR, 'ErrorLogger failed: ' + e.getMessage());
        }
    }

    /**
     * Log an exception
     * @param e The exception to log
     * @param formId ID of the form that had the error
     */
    public static void logException(Exception e, String formId) {
        log(e.getMessage(), e.getStackTraceString(), formId);
    }

    /**
     * Log an error without form context
     * @param message Error message
     * @param stackTrace Apex stack trace
     */
    public static void log(String message, String stackTrace) {
        log(message, stackTrace, null);
    }
}
