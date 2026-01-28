/**
 * Test class for ErrorLogger
 * Ensures error logging works correctly in all scenarios
 */
@isTest
private class ErrorLoggerTest {

    /**
     * Test logging a simple error message
     */
    @isTest
    static void testLogSimpleMessage() {
        Test.startTest();
        ErrorLogger.log('Test error message', 'Test stack trace', 'testFormId123');
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Error_Message__c, Stack_Trace__c, Form_Id__c, Timestamp__c
            FROM Error_Log__c
        ];

        System.assertEquals(1, logs.size(), 'Should create one error log');
        System.assertEquals('Test error message', logs[0].Error_Message__c);
        System.assertEquals('Test stack trace', logs[0].Stack_Trace__c);
        System.assertEquals('testFormId123', logs[0].Form_Id__c);
        System.assertNotEquals(null, logs[0].Timestamp__c, 'Timestamp should be set');
    }

    /**
     * Test logging without form ID
     */
    @isTest
    static void testLogWithoutFormId() {
        Test.startTest();
        ErrorLogger.log('Error without form', 'Stack trace here');
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Form_Id__c FROM Error_Log__c];

        System.assertEquals(1, logs.size(), 'Should create one error log');
        System.assertEquals(null, logs[0].Form_Id__c, 'Form ID should be null');
    }

    /**
     * Test logging an exception
     */
    @isTest
    static void testLogException() {
        Exception testException;
        try {
            // Force a divide by zero exception
            Integer x = 1 / 0;
        } catch (Exception e) {
            testException = e;
        }

        Test.startTest();
        ErrorLogger.logException(testException, 'formId456');
        Test.stopTest();

        List<Error_Log__c> logs = [
            SELECT Error_Message__c, Stack_Trace__c, Form_Id__c
            FROM Error_Log__c
        ];

        System.assertEquals(1, logs.size(), 'Should create one error log');
        System.assert(logs[0].Error_Message__c.contains('Divide by 0'),
                      'Message should contain divide by zero error');
        System.assert(String.isNotBlank(logs[0].Stack_Trace__c),
                      'Stack trace should not be blank');
        System.assertEquals('formId456', logs[0].Form_Id__c);
    }

    /**
     * Test logging multiple errors
     */
    @isTest
    static void testLogMultipleErrors() {
        Test.startTest();
        ErrorLogger.log('Error 1', 'Stack 1', 'form1');
        ErrorLogger.log('Error 2', 'Stack 2', 'form2');
        ErrorLogger.log('Error 3', 'Stack 3', 'form3');
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Error_Message__c FROM Error_Log__c ORDER BY CreatedDate];

        System.assertEquals(3, logs.size(), 'Should create three error logs');
    }

    /**
     * Test logging with null message (should still work)
     */
    @isTest
    static void testLogNullMessage() {
        Test.startTest();
        ErrorLogger.log(null, null, null);
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Error_Message__c FROM Error_Log__c];
        System.assertEquals(1, logs.size(), 'Should create error log even with nulls');
    }

    /**
     * Test logging with very long message (should truncate gracefully)
     */
    @isTest
    static void testLogLongMessage() {
        String longMessage = '';
        for (Integer i = 0; i < 1000; i++) {
            longMessage += 'This is a very long error message that repeats. ';
        }

        Test.startTest();
        ErrorLogger.log(longMessage, longMessage, 'formId');
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Error_Message__c FROM Error_Log__c];
        System.assertEquals(1, logs.size(), 'Should create error log with long message');
    }
}
