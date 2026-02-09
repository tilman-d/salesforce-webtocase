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
     * Test async path is triggered when totalChunks > 3
     * The Queueable should be enqueued and response should have processing: true
     */
    @isTest
    static void testUploadFileChunkAsyncPath() {
        // Create a Case first
        Case testCase = new Case(Subject = 'Test Async Path', Status = 'New');
        insert testCase;

        String fileName = 'large-document.pdf';
        String uploadKey = 'test-async-upload-key';

        // Upload 4 chunks (first 3 are not the last chunk)
        for (Integer i = 0; i < 3; i++) {
            String chunkData = EncodingUtil.base64Encode(Blob.valueOf('Chunk' + i + 'Data-'));
            Map<String, Object> chunkResult = CaseFormController.uploadFileChunk(
                testCase.Id, fileName, chunkData, i, 4, uploadKey
            );
            System.assertEquals(true, chunkResult.get('success'), 'Chunk ' + i + ' should succeed');
            System.assertEquals(false, chunkResult.get('complete'), 'Should not be complete yet');
        }

        // Upload the 4th (last) chunk - should trigger async path
        Test.startTest();
        String lastChunkData = EncodingUtil.base64Encode(Blob.valueOf('Chunk3Data'));
        Map<String, Object> result = CaseFormController.uploadFileChunk(
            testCase.Id, fileName, lastChunkData, 3, 4, uploadKey
        );
        Test.stopTest(); // Executes the Queueable synchronously

        System.assertEquals(true, result.get('success'), 'Last chunk should succeed');
        System.assertEquals(true, result.get('processing'), 'Should indicate async processing');
        System.assertEquals(uploadKey, result.get('uploadKey'), 'Should return uploadKey for polling');

        // After Test.stopTest(), the Queueable has executed
        // Verify the final file was created
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :testCase.Id
        ];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdls) {
            docIds.add(cdl.ContentDocumentId);
        }
        List<ContentVersion> finalFiles = [
            SELECT Title, VersionData FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND Title = :fileName AND IsLatest = true
        ];
        System.assertEquals(1, finalFiles.size(), 'Final file should be created by Queueable');
        System.assertEquals(fileName, finalFiles[0].Title, 'File name should match');
    }

    /**
     * Test server-side file size validation rejects files exceeding 4MB
     */
    @isTest
    static void testServerSideFileSizeValidation() {
        Case testCase = new Case(Subject = 'Test Size Validation', Status = 'New');
        insert testCase;

        String fileName = 'too-large.pdf';
        String uploadKey = 'test-size-key';

        // Simulate a file that would be 7 chunks (7 * 750KB = 5.25MB, exceeds 4MB)
        // Upload first 6 chunks
        for (Integer i = 0; i < 6; i++) {
            String chunkData = EncodingUtil.base64Encode(Blob.valueOf('X'.repeat(100)));
            CaseFormController.uploadFileChunk(testCase.Id, fileName, chunkData, i, 7, uploadKey);
        }

        Test.startTest();
        // Upload the 7th (last) chunk - should be rejected by size validation
        String lastChunkData = EncodingUtil.base64Encode(Blob.valueOf('X'.repeat(100)));
        Map<String, Object> result = CaseFormController.uploadFileChunk(
            testCase.Id, fileName, lastChunkData, 6, 7, uploadKey
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail due to size limit');
        System.assert(((String)result.get('error')).contains('4MB'), 'Error should mention 4MB limit');
    }

    /**
     * Test checkUploadStatus returns 'complete' when final file exists
     */
    @isTest
    static void testCheckUploadStatusComplete() {
        Case testCase = new Case(Subject = 'Test Status Complete', Status = 'New');
        insert testCase;

        // Create a final file on the Case
        ContentVersion cv = new ContentVersion();
        cv.Title = 'completed-file.pdf';
        cv.PathOnClient = 'completed-file.pdf';
        cv.VersionData = Blob.valueOf('Test content');
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = insertedCv.ContentDocumentId;
        cdl.LinkedEntityId = testCase.Id;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        Test.startTest();
        Map<String, Object> result = CaseFormController.checkUploadStatus(
            testCase.Id, 'any-upload-key', 'completed-file.pdf'
        );
        Test.stopTest();

        System.assertEquals('complete', result.get('status'), 'Status should be complete');
    }

    /**
     * Test checkUploadStatus returns 'processing' when chunks still exist
     */
    @isTest
    static void testCheckUploadStatusProcessing() {
        Case testCase = new Case(Subject = 'Test Status Processing', Status = 'New');
        insert testCase;

        String uploadKey = 'processing-test-key';

        // Create a chunk file on the Case (simulating in-progress assembly)
        String chunkTitle = '__chunk__' + uploadKey + '__0__4__test-file.pdf';
        ContentVersion cv = new ContentVersion();
        cv.Title = chunkTitle;
        cv.PathOnClient = chunkTitle + '.tmp';
        cv.VersionData = Blob.valueOf('chunk data');
        cv.FirstPublishLocationId = testCase.Id;
        insert cv;

        Test.startTest();
        Map<String, Object> result = CaseFormController.checkUploadStatus(
            testCase.Id, uploadKey, 'test-file.pdf'
        );
        Test.stopTest();

        System.assertEquals('processing', result.get('status'), 'Status should be processing');
    }

    /**
     * Test checkUploadStatus returns 'processing' when no chunks and no final file
     * (race condition: Queueable may have deleted chunks but not yet created final file)
     */
    @isTest
    static void testCheckUploadStatusProcessingRaceCondition() {
        Case testCase = new Case(Subject = 'Test Status Processing Race', Status = 'New');
        insert testCase;

        Test.startTest();
        Map<String, Object> result = CaseFormController.checkUploadStatus(
            testCase.Id, 'nonexistent-key', 'nonexistent-file.pdf'
        );
        Test.stopTest();

        System.assertEquals('processing', result.get('status'), 'Status should be processing (race condition safe)');
    }

    /**
     * Test checkUploadStatus returns 'error' when recent error log exists
     */
    @isTest
    static void testCheckUploadStatusWithErrorLog() {
        Case testCase = new Case(Subject = 'Test Status Error Log', Status = 'New');
        insert testCase;

        // Create a recent error log for this case
        ErrorLogger.log('FileAssemblyQueueable: test error', 'stack trace', testCase.Id);

        Test.startTest();
        Map<String, Object> result = CaseFormController.checkUploadStatus(
            testCase.Id, 'failed-key', 'failed-file.pdf'
        );
        Test.stopTest();

        System.assertEquals('error', result.get('status'), 'Status should be error when error log exists');
    }

    /**
     * Test chunkIndex bounds validation rejects invalid indices
     */
    @isTest
    static void testUploadFileChunkInvalidIndex() {
        Case testCase = new Case(Subject = 'Test Invalid Index', Status = 'New');
        insert testCase;

        String chunkData = EncodingUtil.base64Encode(Blob.valueOf('test'));

        Test.startTest();

        // Negative chunkIndex
        Map<String, Object> r1 = CaseFormController.uploadFileChunk(
            testCase.Id, 'file.txt', chunkData, -1, 3, 'key1'
        );
        System.assertEquals(false, r1.get('success'), 'Should fail with negative chunkIndex');

        // chunkIndex >= totalChunks
        Map<String, Object> r2 = CaseFormController.uploadFileChunk(
            testCase.Id, 'file.txt', chunkData, 3, 3, 'key2'
        );
        System.assertEquals(false, r2.get('success'), 'Should fail with chunkIndex >= totalChunks');

        // totalChunks < 1
        Map<String, Object> r3 = CaseFormController.uploadFileChunk(
            testCase.Id, 'file.txt', chunkData, 0, 0, 'key3'
        );
        System.assertEquals(false, r3.get('success'), 'Should fail with totalChunks < 1');

        Test.stopTest();
    }

    /**
     * Test uploadKey sanitization strips double underscores
     */
    @isTest
    static void testUploadKeySanitization() {
        Case testCase = new Case(Subject = 'Test Key Sanitization', Status = 'New');
        insert testCase;

        String chunkData = EncodingUtil.base64Encode(Blob.valueOf('test data'));
        // uploadKey with __ should be sanitized to -
        String uploadKey = 'bad__key__here';

        Test.startTest();
        Map<String, Object> result = CaseFormController.uploadFileChunk(
            testCase.Id, 'file.txt', chunkData, 0, 1, uploadKey
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed with sanitized key');
        System.assertEquals(true, result.get('complete'), 'Single chunk should complete');
    }

    /**
     * Test synchronous assembly still works for 3 or fewer chunks
     */
    @isTest
    static void testSyncPathStillWorksForSmallFiles() {
        Case testCase = new Case(Subject = 'Test Sync Path', Status = 'New');
        insert testCase;

        String fileName = 'small-document.txt';
        String uploadKey = 'test-sync-key';

        // Upload 3 chunks (sync path: totalChunks <= 3)
        String chunk1Data = EncodingUtil.base64Encode(Blob.valueOf('Part1-'));
        String chunk2Data = EncodingUtil.base64Encode(Blob.valueOf('Part2-'));
        String chunk3Data = EncodingUtil.base64Encode(Blob.valueOf('Part3'));

        Map<String, Object> r1 = CaseFormController.uploadFileChunk(testCase.Id, fileName, chunk1Data, 0, 3, uploadKey);
        System.assertEquals(true, r1.get('success'));
        System.assertEquals(false, r1.get('complete'));

        Map<String, Object> r2 = CaseFormController.uploadFileChunk(testCase.Id, fileName, chunk2Data, 1, 3, uploadKey);
        System.assertEquals(true, r2.get('success'));
        System.assertEquals(false, r2.get('complete'));

        Test.startTest();
        Map<String, Object> r3 = CaseFormController.uploadFileChunk(testCase.Id, fileName, chunk3Data, 2, 3, uploadKey);
        Test.stopTest();

        // Sync path should return complete: true (NOT processing: true)
        System.assertEquals(true, r3.get('success'), 'Should succeed');
        System.assertEquals(true, r3.get('complete'), 'Should be complete (sync path)');
        System.assertEquals(null, r3.get('processing'), 'Should NOT have processing flag (sync path)');

        // Verify file content
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :testCase.Id
        ];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdls) {
            docIds.add(cdl.ContentDocumentId);
        }
        List<ContentVersion> finalFiles = [
            SELECT Title, VersionData FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND Title = :fileName AND IsLatest = true
        ];
        System.assertEquals(1, finalFiles.size(), 'Final file should exist');
        System.assertEquals('Part1-Part2-Part3', finalFiles[0].VersionData.toString(), 'Content should match');
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

    /**
     * Mock class for successful reCAPTCHA v3 verification with high score
     */
    private class RecaptchaMockV3HighScore implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true, "score": 0.9, "action": "submit"}');
            return res;
        }
    }

    /**
     * Mock class for successful reCAPTCHA v3 verification with low score
     */
    private class RecaptchaMockV3LowScore implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true, "score": 0.1, "action": "submit"}');
            return res;
        }
    }

    /**
     * Mock class for reCAPTCHA v3 verification with wrong action
     */
    private class RecaptchaMockV3WrongAction implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true, "score": 0.9, "action": "homepage"}');
            return res;
        }
    }

    /**
     * Test getCaptchaType method returns configured type
     */
    @isTest
    static void testGetCaptchaTypeConfigured() {
        // Create reCAPTCHA settings with v3 type
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key',
            Captcha_Type__c = 'V3_Score',
            Score_Threshold__c = 0.5
        );
        insert settings;

        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'test-form');
        Test.setCurrentPage(pageRef);

        CaseFormController controller = new CaseFormController();

        Test.startTest();
        String captchaType = controller.getCaptchaType();
        Test.stopTest();

        System.assertEquals('V3_Score', captchaType, 'Captcha type should be V3_Score');
    }

    /**
     * Test getCaptchaType method defaults to V2_Checkbox
     */
    @isTest
    static void testGetCaptchaTypeDefault() {
        PageReference pageRef = Page.CaseFormPage;
        pageRef.getParameters().put('name', 'test-form');
        Test.setCurrentPage(pageRef);

        CaseFormController controller = new CaseFormController();

        Test.startTest();
        String captchaType = controller.getCaptchaType();
        Test.stopTest();

        System.assertEquals('V2_Checkbox', captchaType, 'Captcha type should default to V2_Checkbox');
    }

    /**
     * Test v3 submission with high score passes
     */
    @isTest
    static void testSubmitFormV3HighScorePasses() {
        // Create reCAPTCHA settings with v3 type
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key',
            Captcha_Type__c = 'V3_Score',
            Score_Threshold__c = 0.3
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test V3 High Score'
        };

        Test.setMock(HttpCalloutMock.class, new RecaptchaMockV3HighScore());

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            'test-v3-token'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed with high v3 score');
    }

    /**
     * Test v3 submission with low score fails
     */
    @isTest
    static void testSubmitFormV3LowScoreFails() {
        // Create reCAPTCHA settings with v3 type
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key',
            Captcha_Type__c = 'V3_Score',
            Score_Threshold__c = 0.3
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test V3 Low Score'
        };

        Test.setMock(HttpCalloutMock.class, new RecaptchaMockV3LowScore());

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            'test-v3-token'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Submission should fail with low v3 score');
        System.assert(((String)result.get('error')).contains('security'), 'Error should mention security');
    }

    /**
     * Test v3 submission with wrong action fails
     */
    @isTest
    static void testSubmitFormV3WrongActionFails() {
        // Create reCAPTCHA settings with v3 type
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key',
            Captcha_Type__c = 'V3_Score',
            Score_Threshold__c = 0.3
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test V3 Wrong Action'
        };

        Test.setMock(HttpCalloutMock.class, new RecaptchaMockV3WrongAction());

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            'test-v3-token'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Submission should fail with wrong action');
        System.assert(((String)result.get('error')).contains('Security'), 'Error should mention security');
    }

    /**
     * Test v2 Invisible type works like v2 Checkbox (basic success)
     */
    @isTest
    static void testSubmitFormV2InvisibleSuccess() {
        // Create reCAPTCHA settings with v2 Invisible type
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key',
            Captcha_Type__c = 'V2_Invisible'
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test V2 Invisible'
        };

        Test.setMock(HttpCalloutMock.class, new RecaptchaMockSuccess());

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            'test-invisible-token'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed with v2 Invisible');
    }

    /**
     * Test v3 with custom threshold
     */
    @isTest
    static void testSubmitFormV3CustomThreshold() {
        // Create reCAPTCHA settings with v3 type and high threshold
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'test-site-key',
            Secret_Key__c = 'test-secret-key',
            Captcha_Type__c = 'V3_Score',
            Score_Threshold__c = 0.8  // Higher than default 0.3
        );
        insert settings;

        Form__c captchaForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'captcha-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test V3 Custom Threshold'
        };

        // Mock returns score of 0.9 which is above 0.8 threshold
        Test.setMock(HttpCalloutMock.class, new RecaptchaMockV3HighScore());

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            captchaForm.Id,
            fieldValues,
            '',
            '',
            'test-v3-token'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed with score above custom threshold');
    }

    /**
     * Test form submission with default case values applied
     */
    @isTest
    static void testSubmitFormWithDefaultValues() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];
        testForm.Default_Case_Values__c = '{"Priority":"High","Type":"Problem"}';
        update testForm;

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test With Defaults',
            'SuppliedEmail' => 'defaults@example.com'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id, fieldValues, '', '', ''
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed');

        Case createdCase = [SELECT Priority, Type, Origin, Status FROM Case WHERE Subject = 'Test With Defaults'];
        System.assertEquals('High', createdCase.Priority, 'Priority should be High from defaults');
        System.assertEquals('Problem', createdCase.Type, 'Type should be Problem from defaults');
        System.assertEquals('Web Form', createdCase.Origin, 'Origin should still be Web Form');
    }

    /**
     * Test default values can override Origin and Status
     */
    @isTest
    static void testSubmitFormDefaultsOverrideOriginStatus() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];
        testForm.Default_Case_Values__c = '{"Origin":"Partner Form","Status":"Escalated"}';
        update testForm;

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test Override Origin Status'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id, fieldValues, '', '', ''
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed');

        Case createdCase = [SELECT Origin, Status FROM Case WHERE Subject = 'Test Override Origin Status'];
        System.assertEquals('Partner Form', createdCase.Origin, 'Origin should be overridden');
        System.assertEquals('Escalated', createdCase.Status, 'Status should be overridden');
    }

    /**
     * Test invalid JSON in defaults is handled gracefully
     */
    @isTest
    static void testSubmitFormDefaultsInvalidJson() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];
        testForm.Default_Case_Values__c = '{not valid json}';
        update testForm;

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test Invalid JSON Defaults'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id, fieldValues, '', '', ''
        );
        Test.stopTest();

        // Should still succeed - invalid JSON is logged and skipped
        System.assertEquals(true, result.get('success'), 'Submission should succeed despite invalid JSON');

        Case createdCase = [SELECT Origin, Status FROM Case WHERE Subject = 'Test Invalid JSON Defaults'];
        System.assertEquals('Web Form', createdCase.Origin, 'Origin should be default fallback');
        System.assertEquals('New', createdCase.Status, 'Status should be default fallback');

        // Verify error was logged
        List<Error_Log__c> logs = [SELECT Error_Message__c FROM Error_Log__c WHERE Form_Id__c = :testForm.Id];
        System.assert(logs.size() > 0, 'Error should be logged for invalid JSON');
    }

    /**
     * Test disallowed fields in defaults are silently ignored
     */
    @isTest
    static void testSubmitFormDefaultsBlocksDisallowedFields() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];
        // Manually set field to bypass admin validation (simulating DB-level data)
        testForm.Default_Case_Values__c = '{"Priority":"High","AccountId":"001000000000001","Subject":"Hacked"}';
        update testForm;

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test Disallowed Fields'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id, fieldValues, '', '', ''
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed');

        Case createdCase = [SELECT Subject, Priority, AccountId FROM Case WHERE Subject = 'Test Disallowed Fields'];
        System.assertEquals('High', createdCase.Priority, 'Allowed field Priority should be applied');
        System.assertEquals(null, createdCase.AccountId, 'Disallowed AccountId should be ignored');
        System.assertEquals('Test Disallowed Fields', createdCase.Subject, 'User-supplied Subject should win');
    }

    /**
     * Test non-string JSON values are safely skipped
     */
    @isTest
    static void testSubmitFormDefaultsNonStringValues() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];
        testForm.Default_Case_Values__c = '{"Priority":123,"Type":"Problem"}';
        update testForm;

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test Non-String Values'
        };

        Test.startTest();
        Map<String, Object> result = CaseFormController.submitForm(
            testForm.Id, fieldValues, '', '', ''
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Submission should succeed');

        Case createdCase = [SELECT Priority, Type FROM Case WHERE Subject = 'Test Non-String Values'];
        // String.valueOf(123) = '123' which is non-blank, so it gets applied as a string
        // The DML may or may not succeed depending on org picklist config
        // But the important thing is: Type should be 'Problem'
        System.assertEquals('Problem', createdCase.Type, 'Type should be set from defaults');
    }

    /**
     * Test submitForm returns caseId for chunked uploads
     */
    @isTest
    static void testSubmitFormReturnsCaseId() {
        Form__c testForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form' LIMIT 1];

        Map<String, String> fieldValues = new Map<String, String>{
            'Subject' => 'Test CaseId Return'
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
        System.assertNotEquals(null, result.get('caseId'), 'caseId should be returned');
        System.assertNotEquals(null, result.get('caseNumber'), 'caseNumber should be returned');
    }

    /**
     * Test chunked file upload - single chunk (small file)
     */
    @isTest
    static void testUploadFileChunkSingleChunk() {
        // Create a Case first
        Case testCase = new Case(Subject = 'Test Chunked Upload', Status = 'New');
        insert testCase;

        String fileName = 'test-small-file.txt';
        String fileContent = 'Hello World - Small File Content';
        String base64Content = EncodingUtil.base64Encode(Blob.valueOf(fileContent));
        String uploadKey = 'test-upload-key-123';

        Test.startTest();
        Map<String, Object> result = CaseFormController.uploadFileChunk(
            testCase.Id,
            fileName,
            base64Content,
            0,  // First chunk (0-indexed)
            1,  // Total 1 chunk
            uploadKey
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Chunk upload should succeed');
        System.assertEquals(true, result.get('complete'), 'Single chunk should complete the upload');

        // Verify file was attached
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testCase.Id
        ];
        System.assertEquals(1, cdls.size(), 'File should be attached to case');

        // Verify file content
        ContentVersion cv = [
            SELECT Title, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :cdls[0].ContentDocumentId
            AND IsLatest = true
        ];
        System.assertEquals(fileName, cv.Title, 'File name should match');
        System.assertEquals(fileContent, cv.VersionData.toString(), 'File content should match');
    }

    /**
     * Test chunked file upload - multiple chunks
     */
    @isTest
    static void testUploadFileChunkMultipleChunks() {
        // Create a Case first
        Case testCase = new Case(Subject = 'Test Multi-Chunk Upload', Status = 'New');
        insert testCase;

        String fileName = 'test-large-file.txt';
        String uploadKey = 'test-multi-chunk-key';

        // Simulate a file split into 3 chunks
        String chunk1Data = EncodingUtil.base64Encode(Blob.valueOf('Chunk 1 Data - '));
        String chunk2Data = EncodingUtil.base64Encode(Blob.valueOf('Chunk 2 Data - '));
        String chunk3Data = EncodingUtil.base64Encode(Blob.valueOf('Chunk 3 Data'));

        Test.startTest();

        // Upload chunk 1
        Map<String, Object> result1 = CaseFormController.uploadFileChunk(
            testCase.Id, fileName, chunk1Data, 0, 3, uploadKey
        );
        System.assertEquals(true, result1.get('success'), 'Chunk 1 should succeed');
        System.assertEquals(false, result1.get('complete'), 'Should not be complete after chunk 1');

        // Upload chunk 2
        Map<String, Object> result2 = CaseFormController.uploadFileChunk(
            testCase.Id, fileName, chunk2Data, 1, 3, uploadKey
        );
        System.assertEquals(true, result2.get('success'), 'Chunk 2 should succeed');
        System.assertEquals(false, result2.get('complete'), 'Should not be complete after chunk 2');

        // Upload chunk 3 (last)
        Map<String, Object> result3 = CaseFormController.uploadFileChunk(
            testCase.Id, fileName, chunk3Data, 2, 3, uploadKey
        );
        System.assertEquals(true, result3.get('success'), 'Chunk 3 should succeed');
        System.assertEquals(true, result3.get('complete'), 'Should be complete after last chunk');

        Test.stopTest();

        // Verify file was attached
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testCase.Id
        ];
        System.assertEquals(1, cdls.size(), 'File should be attached to case');

        // Verify combined content
        ContentVersion cv = [
            SELECT Title, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :cdls[0].ContentDocumentId
            AND IsLatest = true
        ];
        System.assertEquals(fileName, cv.Title, 'File name should match');
        System.assertEquals('Chunk 1 Data - Chunk 2 Data - Chunk 3 Data', cv.VersionData.toString(), 'Combined content should match');

        // Verify chunk files were cleaned up
        String chunkPattern = '__chunk__' + uploadKey + '%';
        List<ContentVersion> chunks = [
            SELECT Id FROM ContentVersion WHERE Title LIKE :chunkPattern
        ];
        System.assertEquals(0, chunks.size(), 'Chunk files should be deleted after assembly');
    }

    /**
     * Test chunked upload with missing parameters
     */
    @isTest
    static void testUploadFileChunkMissingParams() {
        Test.startTest();

        // Missing caseId
        Map<String, Object> result1 = CaseFormController.uploadFileChunk(
            '', 'file.txt', 'data', 0, 1, 'key'
        );
        System.assertEquals(false, result1.get('success'), 'Should fail with missing caseId');

        // Missing fileName
        Map<String, Object> result2 = CaseFormController.uploadFileChunk(
            'a00000000000001', '', 'data', 0, 1, 'key'
        );
        System.assertEquals(false, result2.get('success'), 'Should fail with missing fileName');

        // Missing uploadKey
        Map<String, Object> result3 = CaseFormController.uploadFileChunk(
            'a00000000000001', 'file.txt', 'data', 0, 1, ''
        );
        System.assertEquals(false, result3.get('success'), 'Should fail with missing uploadKey');

        Test.stopTest();
    }

    /**
     * Test chunked upload with invalid case ID
     */
    @isTest
    static void testUploadFileChunkInvalidCaseId() {
        Test.startTest();
        Map<String, Object> result = CaseFormController.uploadFileChunk(
            '500000000000000', // Non-existent case
            'file.txt',
            EncodingUtil.base64Encode(Blob.valueOf('test')),
            0,
            1,
            'test-key'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail with invalid case ID');
        System.assert(((String)result.get('error')).contains('Case not found'), 'Error should mention case not found');
    }

    /**
     * Test getChunkSize returns expected value
     */
    @isTest
    static void testGetChunkSize() {
        Test.startTest();
        Integer chunkSize = CaseFormController.getChunkSize();
        Test.stopTest();

        System.assertEquals(750000, chunkSize, 'Chunk size should be 750000 bytes');
    }
}
