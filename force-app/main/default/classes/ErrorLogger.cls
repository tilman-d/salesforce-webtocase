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
    public static void log(String message, String stackTrace, String formId) {
        try {
            Error_Log__c errorLog = new Error_Log__c(
                Timestamp__c = DateTime.now(),
                Error_Message__c = message,
                Stack_Trace__c = stackTrace,
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
