/**
 * Test class for CaseFormController and ErrorLogger
 * Tests form loading, case creation, file attachment, and reCAPTCHA verification
 */
@isTest
private class CaseFormControllerTest {

    /**
     * Setup test data - creates a form with fields
     */
    @TestSetup
    static void setupTestData() {
        // Create test form
        Form__c testForm = new Form__c(
            Form_Name__c = 'test-form',
            Title__c = 'Test Form',
            Description__c = 'Test description',
            Success_Message__c = 'Thank you for your submission!',
            Active__c = true,
            Enable_File_Upload__c = true,
            Max_File_Size_MB__c = 5,
            Enable_Captcha__c = false
        );
        insert testForm;

        // Create test fields
        List<Form_Field__c> fields = new List<Form_Field__c>{
            new Form_Field__c(
                Form__c = testForm.Id,
                Field_Label__c = 'Your Name',
                Field_Type__c = 'Text',
                Case_Field__c = 'SuppliedName',
                Required__c = true,
                Sort_Order__c = 1
            ),
            new Form_Field__c(
                Form__c = testForm.Id,
                Field_Label__c = 'Email',
                Field_Type__c = 'Email',
                Case_Field__c = 'SuppliedEmail',
                Required__c = true,
                Sort_Order__c = 2
            ),
            new Form_Field__c(
                Form__c = testForm.Id,
                Field_Label__c = 'Subject',
                Field_Type__c = 'Text',
                Case_Field__c = 'Subject',
                Required__c = true,
                Sort_Order__c = 3
            ),
            new Form_Field__c(
                Form__c = testForm.Id,
                Field_Label__c = 'Message',
                Field_Type__c = 'Textarea',
                Case_Field__c = 'Description',
                Required__c = false,
                Sort_Order__c = 4
            )
        };
        insert fields;

        // Create inactive form for testing
        Form__c inactiveForm = new Form__c(
            Form_Name__c = 'inactive-form',
            Title__c = 'Inactive Form',
            Active__c = false
        );
        insert inactiveForm;

        // Create captcha-enabled form for testing
        Form__c captchaForm = new Form__c(
            Form_Name__c = 'captcha-form',
            Title__c = 'Captcha Form',
            Active__c = true,
            Enable_Captcha__c = true
        );
        insert captchaForm;
    }

    /**
     * Test controller constructor loads form correctly
     */
    @isTest
    static void testControllerLoadsForm() {
        // Set up page parameters
        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'test-form');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        CaseFormController controller = new CaseFormController();
        Test.stopTest();

        // Verify form loaded
        System.assertNotEquals(null, controller.form, 'Form should be loaded');
        System.assertEquals('Test Form', controller.form.Title__c, 'Form title should match');
        System.assertEquals(4, controller.fields.size(), 'Should have 4 fields');
        System.assertEquals('Your Name', controller.fields[0].Field_Label__c, 'First field should be Your Name');
    }

    /**
     * Test controller handles missing form name
     */
    @isTest
    static void testControllerNoFormName() {
        PageReference pageRef = Page.CaseFormPage;
        Test.setCurrentPage(pageRef);

        Test.startTest();
        CaseFormController controller = new CaseFormController();
        Test.stopTest();

        System.assertEquals(null, controller.form, 'Form should be null when no name provided');
    }

    /**
     * Test controller handles inactive form
     */
    @isTest
    static void testControllerInactiveForm() {
        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'inactive-form');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        CaseFormController controller = new CaseFormController();
        Test.stopTest();

        System.assertEquals(null, controller.form, 'Inactive form should not be loaded');
    }

    /**
     * Test controller handles non-existent form
     */
    @isTest
    static void testControllerNonExistentForm() {
        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'does-not-exist');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        CaseFormController controller = new CaseFormController();
        Test.stopTest();

        System.assertEquals(null, controller.form, 'Non-existent form should not be loaded');
    }

    /**
     * Test successful form submission without file
     */
    @isTest
    static void testSubmitFormWithoutFile() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'SuppliedName' => 'John Doe',
            'SuppliedEmail' => 'john@example.com',
            'Subject' => 'Test Subject',
            'Description' => 'Test Description'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id,
            fieldValues,
            '',
            '',
            ''  // No captcha token for non-captcha form
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed');
        System.assertNotEquals(null, result.get('caseNumber'), 'Case number should be returned');

        // Verify Case was created
        List<Case> cases = [SELECT Subject, Description, SuppliedName, SuppliedEmail, Origin
                           FROM Case WHERE Subject = 'Test Subject'];
        System.assertEquals(1, cases.size(), 'One case should be created');
        System.assertEquals('John Doe', cases[0].SuppliedName, 'SuppliedName should match');
        System.assertEquals('john@example.com', cases[0].SuppliedEmail, 'SuppliedEmail should match');
        System.assertEquals('Web Form', cases[0].Origin, 'Origin should be Web Form');
    }

    /**
     * Test form submission with file attachment
     */
    @isTest
    static void testSubmitFormWithFile() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test With File',
            'SuppliedEmail' => 'test@example.com'
        };

        // Create small test file content (base64 encoded "Hello World")
        String fileContent = EncodingUtil.base64Encode(Blob.valueOf('Hello World Test File'));

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id,
            fieldValues,
            'test-file.txt',
            fileContent,
            ''  // No captcha token for non-captcha form
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed');

        // Verify Case and file attachment
        Case createdCase = [SELECT Id, Subject FROM Case WHERE Subject = 'Test With File' LIMIT 1];
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :createdCase.Id
        ];
        System.assertEquals(1, cdls.size(), 'One file should be attached');
    }

    /**
     * Test form submission with invalid form ID
     */
    @isTest
    static void testSubmitFormInvalidFormId() {
        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            'a0000000000FAKE', // Invalid ID
            fieldValues,
            '',
            '',
            ''
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Submission should fail');
        System.assertNotEquals(null, result.get('error'), 'Error message should be returned');
    }

    /**
     * Test form submission with empty field values
     */
    @isTest
    static void testSubmitFormEmptyFields() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>();

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id,
            fieldValues,
            '',
            '',
            ''
        );
        Test.stopTest();

        // Should still succeed - validation is client-side
        System.assertEquals(true, result.get('success'), 'Submission should succeed even with empty fields');
    }

    /**
     * Test form submission with null field values
     */
    @isTest
    static void testSubmitFormNullFields() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id,
            null,
            '',
            '',
            ''
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed with null fields');
    }

    /**
     * Test form submission with SuppliedPhone and SuppliedCompany
     */
    @isTest
    static void testSubmitFormAllFields() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'SuppliedName' => 'Jane Smith',
            'SuppliedEmail' => 'jane@example.com',
            'SuppliedPhone' => '555-1234',
            'SuppliedCompany' => 'Acme Corp',
            'Subject' => 'All Fields Test',
            'Description' => 'Testing all fields'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id,
            fieldValues,
            '',
            '',
            ''
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed');

        Case createdCase = [SELECT SuppliedPhone, SuppliedCompany FROM Case WHERE Subject = 'All Fields Test'];
        System.assertEquals('555-1234', createdCase.SuppliedPhone, 'Phone should match');
        System.assertEquals('Acme Corp', createdCase.SuppliedCompany, 'Company should match');
    }

    /**
     * Test ErrorLogger.log method
     */
    @isTest
    static void testErrorLogger() {
        Test.startTest();
        ErrorLogger.log('Test error message', 'Test stack trace', 'testFormId');
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Error_Message__c, Stack_Trace__c, Form_Id__c
                                   FROM Error_Log__c];
        System.assertEquals(1, logs.size(), 'One error log should be created');
        System.assertEquals('Test error message', logs[0].Error_Message__c, 'Message should match');
        System.assertEquals('Test stack trace', logs[0].Stack_Trace__c, 'Stack trace should match');
        System.assertEquals('testFormId', logs[0].Form_Id__c, 'Form ID should match');
    }

    /**
     * Test ErrorLogger.logException method
     */
    @isTest
    static void testErrorLoggerException() {
        Test.startTest();
        try {
            // Force an exception
            Integer x = 1 / 0;
        } catch (Exception e) {
            ErrorLogger.logException(e, 'testFormId');
        }
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Error_Message__c, Stack_Trace__c FROM Error_Log__c];
        System.assertEquals(1, logs.size(), 'One error log should be created');
        System.assert(logs[0].Error_Message__c.contains('Divide by 0'), 'Message should contain divide by zero');
    }

    /**
     * Test ErrorLogger.log without form ID
     */
    @isTest
    static void testErrorLoggerNoFormId() {
        Test.startTest();
        ErrorLogger.log('Error without form', 'Stack trace');
        Test.stopTest();

        List<Error_Log__c> logs = [SELECT Form_Id__c FROM Error_Log__c];
        System.assertEquals(1, logs.size(), 'One error log should be created');
        System.assertEquals(null, logs[0].Form_Id__c, 'Form ID should be null');
    }

    /**
     * Test getCaptchaSiteKey method with no settings
     */
    @isTest
    static void testGetCaptchaSiteKeyNoSettings() {
        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'test-form');
        Test.setCurrentPage(pageRef);

        CaseFormController controller = new CaseFormController();

        Test.startTest();
        String siteKey = controller.getCaptchaSiteKey();
        Test.stopTest();

        // Should return empty string when no settings configured
        System.assertEquals('', siteKey, 'Site key should be empty when no settings');
    }

    /**
     * Test getCaptchaEnabled method with no settings
     */
    @isTest
    static void testGetCaptchaEnabledNoSettings() {
        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'captcha-form');
        Test.setCurrentPage(pageRef);

        CaseFormController controller = new CaseFormController();

        Test.startTest();
        Boolean captchaEnabled = controller.getCaptchaEnabled();
        Test.stopTest();

        // Should return false when captcha enabled on form but no site key configured
        System.assertEquals(false, captchaEnabled, 'Captcha should be disabled when no site key');
    }

    /**
     * Test getCaptchaSiteKey method with settings configured
     */
    @isTest
    static void testGetCaptchaSiteKeyWithSettings() {
        // Create reCAPTCHA settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key-123',
            Secret_Key__c = 'test-secret-key-456'
        );
        insert settings;

        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'test-form');
        Test.setCurrentPage(pageRef);

        CaseFormController controller = new CaseFormController();

        Test.startTest();
        String siteKey = controller.getCaptchaSiteKey();
        Test.stopTest();

        System.assertEquals('test-site-key-123', siteKey, 'Site key should match configured value');
    }

    /**
     * Test getCaptchaEnabled returns true when properly configured
     */
    @isTest
    static void testGetCaptchaEnabledWithSettings() {
        // Create reCAPTCHA settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key-123',
            Secret_Key__c = 'test-secret-key-456'
        );
        insert settings;

        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'captcha-form');
        Test.setCurrentPage(pageRef);

        CaseFormController controller = new CaseFormController();

        Test.startTest();
        Boolean captchaEnabled = controller.getCaptchaEnabled();
        Test.stopTest();

        System.assertEquals(true, captchaEnabled, 'Captcha should be enabled when settings configured');
    }

    /**
     * Test form submission with captcha enabled but no token provided
     */
    @isTest
    static void testSubmitFormCaptchaNoToken() {
        // Create reCAPTCHA settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key'
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test Captcha No Token'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            '' // Empty captcha token
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Submission should fail without captcha token');
        System.assert(((String)result.get('error')).contains('CAPTCHA'), 'Error should mention CAPTCHA');
    }

    /**
     * Test form submission with captcha enabled and mock verification
     */
    @isTest
    static void testSubmitFormCaptchaWithMockVerification() {
        // Create reCAPTCHA settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key'
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test Captcha With Token'
        };

        // Set up mock for HTTP callout
        Test.setMock(HttpCalloutMock.class, new RecaptchaMockSuccess());

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            'test-captcha-token'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed with valid captcha');
    }

    /**
     * Test form submission with captcha verification failure
     */
    @isTest
    static void testSubmitFormCaptchaVerificationFails() {
        // Create reCAPTCHA settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key'
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test Captcha Fail'
        };

        // Set up mock for HTTP callout that returns failure
        Test.setMock(HttpCalloutMock.class, new RecaptchaMockFailure());

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            'invalid-captcha-token'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Submission should fail with invalid captcha');
        System.assert(((String)result.get('error')).contains('CAPTCHA'), 'Error should mention CAPTCHA');
    }

    /**
     * Test form without captcha enabled ignores captcha token
     */
    @isTest
    static void testSubmitFormNoCaptchaIgnoresToken() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test No Captcha'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id,
            fieldValues,
            '',
            '',
            '' // Empty token should be ignored
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed without captcha');
    }

    /**
     * Test controller loads form with Enable_Captcha__c field
     */
    @isTest
    static void testControllerLoadsCaptchaForm() {
        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'captcha-form');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        CaseFormController controller = new CaseFormController();
        Test.stopTest();

        System.assertNotEquals(null, controller.form, 'Form should be loaded');
        System.assertEquals(true, controller.form.Enable_Captcha__c, 'Enable_Captcha__c should be true');
    }

    /**
     * Mock class for successful reCAPTCHA verification
     */
    private class RecaptchaMockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }

    /**
     * Mock class for failed reCAPTCHA verification
     */
    private class RecaptchaMockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": false, "error-codes": ["invalid-input-response"]}');
            return res;
        }
    }
}
