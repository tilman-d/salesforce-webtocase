/**
 * Test class for WebToCaseRestAPI, WebToCaseNonceService, and WebToCaseRateLimiter
 * Target: 85%+ code coverage
 */
@isTest
private class WebToCaseRestAPITest {

    @TestSetup
    static void setupTestData() {
        // Create test form with allowed domains
        Form__c form = new Form__c(
            Form_Name__c = 'embed-test-form',
            Title__c = 'Embed Test Form',
            Description__c = 'Test form for embedding',
            Active__c = true,
            Enable_File_Upload__c = true,
            Max_File_Size_MB__c = 10,
            Success_Message__c = 'Thank you!',
            Enable_Captcha__c = false,
            Allowed_Domains__c = 'example.com\nmysite.org\nlocalhost:8080'
        );
        insert form;

        // Create test fields
        List<Form_Field__c> fields = new List<Form_Field__c>{
            new Form_Field__c(
                Form__c = form.Id,
                Field_Label__c = 'Name',
                Field_Type__c = 'Text',
                Case_Field__c = 'SuppliedName',
                Required__c = true,
                Sort_Order__c = 1
            ),
            new Form_Field__c(
                Form__c = form.Id,
                Field_Label__c = 'Email',
                Field_Type__c = 'Email',
                Case_Field__c = 'SuppliedEmail',
                Required__c = true,
                Sort_Order__c = 2
            ),
            new Form_Field__c(
                Form__c = form.Id,
                Field_Label__c = 'Subject',
                Field_Type__c = 'Text',
                Case_Field__c = 'Subject',
                Required__c = true,
                Sort_Order__c = 3
            )
        };
        insert fields;

        // Create form without allowed domains (embedding disabled)
        Form__c noEmbedForm = new Form__c(
            Form_Name__c = 'no-embed-form',
            Title__c = 'No Embed Form',
            Active__c = true
        );
        insert noEmbedForm;
    }

    // ==================== REST API Tests ====================

    @isTest
    static void testGetFormConfigSuccess() {
        // Setup mock REST request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://example.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200');

        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('embed-test-form', response.get('formName'), 'Form name should match');
        System.assertEquals('Embed Test Form', response.get('title'), 'Title should match');
        System.assertNotEquals(null, response.get('nonce'), 'Nonce should be present');
        System.assertNotEquals(null, response.get('fields'), 'Fields should be present');

        List<Object> fields = (List<Object>) response.get('fields');
        System.assertEquals(3, fields.size(), 'Should have 3 fields');
    }

    @isTest
    static void testGetFormConfigMissingFormName() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://example.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400');
    }

    @isTest
    static void testGetFormConfigMissingOrigin() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        // No Origin header
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403 for missing origin');
    }

    @isTest
    static void testGetFormConfigUnauthorizedOrigin() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://evil.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403 for unauthorized origin');
    }

    @isTest
    static void testGetFormConfigEmbeddingDisabled() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/no-embed-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://example.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403 when embedding disabled');
    }

    @isTest
    static void testGetFormConfigFormNotFound() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/nonexistent-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://example.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403 for nonexistent form');
    }

    @isTest
    static void testHandleDelete() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'DELETE';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handleDelete();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(405, res.statusCode, 'Should return 405 for DELETE');
    }

    @isTest
    static void testSubmitFormInvalidAction() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/invalid-action';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for invalid action');
    }

    @isTest
    static void testSubmitFormInvalidJson() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/submit';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('invalid json');
        req.headers.put('Origin', 'https://example.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for invalid JSON');
    }

    @isTest
    static void testSubmitFormMissingFields() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/submit';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"formId": "test"}');
        req.headers.put('Origin', 'https://example.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing fields');
    }

    // ==================== Nonce Service Tests ====================

    @isTest
    static void testNonceGenerationAndValidation() {
        // Note: Platform Cache may not be available in test context
        // This test verifies the basic flow but may need cache stubbing

        Test.startTest();
        try {
            String nonce = WebToCaseNonceService.generateNonce(
                'a00000000000000AAA',
                'example.com',
                new List<String>{'Subject', 'Description'}
            );
            System.assertNotEquals(null, nonce, 'Nonce should be generated');
            System.assertEquals(64, nonce.length(), 'Nonce should be 64 chars (hex of 256-bit)');
        } catch (WebToCaseNonceService.NonceException e) {
            // Expected if Platform Cache is not configured
            System.assert(e.getMessage().contains('Server configuration'), 'Should be cache config error');
        }
        Test.stopTest();
    }

    @isTest
    static void testNonceValidateAndConsumeNull() {
        Test.startTest();
        WebToCaseNonceService.NonceData result = WebToCaseNonceService.validateAndConsume(null, 'formId', 'origin');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for null nonce');
    }

    @isTest
    static void testNonceValidateAndConsumeBlank() {
        Test.startTest();
        WebToCaseNonceService.NonceData result = WebToCaseNonceService.validateAndConsume('', 'formId', 'origin');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for blank nonce');
    }

    @isTest
    static void testNonceValidateAndConsumeInvalid() {
        Test.startTest();
        WebToCaseNonceService.NonceData result = WebToCaseNonceService.validateAndConsume(
            'invalid-nonce-that-does-not-exist',
            'formId',
            'origin'
        );
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null for invalid nonce');
    }

    @isTest
    static void testIsFieldAllowedNull() {
        Test.startTest();
        Boolean result = WebToCaseNonceService.isFieldAllowed(null, 'Subject');
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false for null nonce data');
    }

    @isTest
    static void testIsFieldAllowedNullFields() {
        WebToCaseNonceService.NonceData data = new WebToCaseNonceService.NonceData();
        data.allowedFields = null;

        Test.startTest();
        Boolean result = WebToCaseNonceService.isFieldAllowed(data, 'Subject');
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false for null allowed fields');
    }

    @isTest
    static void testIsFieldAllowed() {
        WebToCaseNonceService.NonceData data = new WebToCaseNonceService.NonceData();
        data.allowedFields = new List<String>{'Subject', 'Description'};

        Test.startTest();
        Boolean allowed = WebToCaseNonceService.isFieldAllowed(data, 'Subject');
        Boolean notAllowed = WebToCaseNonceService.isFieldAllowed(data, 'CustomField');
        Test.stopTest();

        System.assertEquals(true, allowed, 'Subject should be allowed');
        System.assertEquals(false, notAllowed, 'CustomField should not be allowed');
    }

    // ==================== Rate Limiter Tests ====================

    @isTest
    static void testRateLimiterCheckAndIncrement() {
        Test.startTest();
        WebToCaseRateLimiter.RateLimitResult result = WebToCaseRateLimiter.checkAndIncrement('test-origin.com');
        Test.stopTest();

        System.assertEquals(true, result.allowed, 'First request should be allowed');
        System.assertEquals(1, result.currentCount, 'Count should be 1');
        System.assertEquals(100, result.limit_x, 'Limit should be 100');
    }

    @isTest
    static void testRateLimiterMultipleRequests() {
        Test.startTest();
        // Make multiple requests
        for (Integer i = 0; i < 5; i++) {
            WebToCaseRateLimiter.checkAndIncrement('multi-request-origin.com');
        }

        WebToCaseRateLimiter.RateLimitResult result = WebToCaseRateLimiter.checkAndIncrement('multi-request-origin.com');
        Test.stopTest();

        System.assertEquals(true, result.allowed, 'Should still be allowed');
        System.assertEquals(6, result.currentCount, 'Count should be 6');
    }

    @isTest
    static void testRateLimiterGetCurrentCount() {
        // First make some requests
        WebToCaseRateLimiter.checkAndIncrement('count-test-origin.com');
        WebToCaseRateLimiter.checkAndIncrement('count-test-origin.com');
        WebToCaseRateLimiter.checkAndIncrement('count-test-origin.com');

        Test.startTest();
        Integer count = WebToCaseRateLimiter.getCurrentCount('count-test-origin.com');
        Integer zeroCount = WebToCaseRateLimiter.getCurrentCount('nonexistent-origin.com');
        Test.stopTest();

        System.assertEquals(3, count, 'Count should be 3');
        System.assertEquals(0, zeroCount, 'Count for nonexistent origin should be 0');
    }

    @isTest
    static void testRateLimiterCleanup() {
        // Create some old counters
        DateTime oldTime = DateTime.now().addHours(-25);
        Rate_Limit_Counter__c oldCounter = new Rate_Limit_Counter__c(
            Origin_Key__c = 'old-test-key-' + System.now().getTime(),
            Origin_Domain__c = 'old-origin.com',
            Count__c = 50,
            Hour_Bucket__c = oldTime
        );
        insert oldCounter;

        Test.startTest();
        WebToCaseRateLimiter.cleanupOldCounters();
        Test.stopTest();

        List<Rate_Limit_Counter__c> remaining = [SELECT Id FROM Rate_Limit_Counter__c WHERE Id = :oldCounter.Id];
        System.assertEquals(0, remaining.size(), 'Old counter should be deleted');
    }

    @isTest
    static void testRateLimiterResult() {
        WebToCaseRateLimiter.RateLimitResult result = new WebToCaseRateLimiter.RateLimitResult(true, 50, 100);

        System.assertEquals(true, result.allowed, 'Allowed should be true');
        System.assertEquals(50, result.currentCount, 'Current count should be 50');
        System.assertEquals(100, result.limit_x, 'Limit should be 100');
        System.assertEquals(0, result.retryAfterSeconds, 'Retry after should default to 0');
    }

    // ==================== Origin Validation Tests ====================

    @isTest
    static void testOriginValidationWithPort() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'http://localhost:8080');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should allow localhost:8080');
    }

    @isTest
    static void testOriginValidationWwwPrefix() {
        // www.example.com should match allowed domain 'example.com'
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://www.example.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'www.example.com should match allowed domain example.com');
    }

    @isTest
    static void testOriginValidationWwwPrefixReverse() {
        // If allowed domain has www. but origin doesn't, should still match
        // Add a form with www. in allowed domains
        Form__c form = new Form__c(
            Form_Name__c = 'www-test-form',
            Title__c = 'WWW Test',
            Active__c = true,
            Allowed_Domains__c = 'www.testsite.org'
        );
        insert form;
        insert new Form_Field__c(
            Form__c = form.Id, Field_Label__c = 'Subject', Field_Type__c = 'Text',
            Case_Field__c = 'Subject', Required__c = true, Sort_Order__c = 1
        );

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/www-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://testsite.org');  // No www
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'testsite.org should match allowed domain www.testsite.org');
    }

    @isTest
    static void testCorsHeadersOnErrorResponse() {
        // Error responses should include CORS headers so developers can read error messages
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://evil.com');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403');
        // CORS headers should still be present for debugging
        System.assertEquals('https://evil.com', res.headers.get('Access-Control-Allow-Origin'),
            'CORS headers should be set even on error responses');
    }

    @isTest
    static void testOriginValidationSubdomainRejection() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'https://evil.example.com');  // Should NOT match example.com
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should reject subdomain spoofing');
    }

    @isTest
    static void testOriginValidationIPv4Rejection() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/form/embed-test-form';
        req.httpMethod = 'GET';
        req.headers.put('Origin', 'http://192.168.1.1');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.getFormConfig();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should reject IP addresses');
    }

    // ==================== Upload Chunk Origin Validation Tests ====================

    @isTest
    static void testUploadChunkMissingFormId() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/upload-chunk';
        req.httpMethod = 'POST';
        req.headers.put('Origin', 'https://example.com');
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'caseId' => 'testCaseId',
            'fileName' => 'test.txt',
            'chunkData' => 'base64data',
            'chunkIndex' => 0,
            'totalChunks' => 1,
            'uploadKey' => 'test-key'
            // formId is missing
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing formId');
    }

    @isTest
    static void testUploadChunkUnauthorizedOrigin() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'embed-test-form' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/upload-chunk';
        req.httpMethod = 'POST';
        req.headers.put('Origin', 'https://evil.com');  // Not in allowed domains
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'caseId' => 'testCaseId',
            'fileName' => 'test.txt',
            'chunkData' => 'base64data',
            'chunkIndex' => 0,
            'totalChunks' => 1,
            'uploadKey' => 'test-key',
            'formId' => form.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403 for unauthorized origin');
    }

    @isTest
    static void testUploadChunkMissingOrigin() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'embed-test-form' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/upload-chunk';
        req.httpMethod = 'POST';
        // No Origin header
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'caseId' => 'testCaseId',
            'fileName' => 'test.txt',
            'chunkData' => 'base64data',
            'chunkIndex' => 0,
            'totalChunks' => 1,
            'uploadKey' => 'test-key',
            'formId' => form.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403 for missing origin');
    }

    @isTest
    static void testUploadChunkWithValidOrigin() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'embed-test-form' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/upload-chunk';
        req.httpMethod = 'POST';
        req.headers.put('Origin', 'https://example.com');  // In allowed domains
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'caseId' => 'invalidCaseId',  // Invalid but that's ok - testing origin validation first
            'fileName' => 'test.txt',
            'chunkData' => 'dGVzdA==',  // Valid base64 for "test"
            'chunkIndex' => 0,
            'totalChunks' => 1,
            'uploadKey' => 'test-key',
            'formId' => form.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        // The call will proceed past origin validation but may fail on case lookup
        // Either 200 (success) or error from CaseFormController, but NOT 403
        System.assertNotEquals(403, res.statusCode, 'Should not reject valid origin');
    }

    // ==================== Upload Status Tests ====================

    @isTest
    static void testUploadStatusSuccess() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'embed-test-form' LIMIT 1];

        // Create a Case and a completed file on it
        Case testCase = new Case(Subject = 'Status Test', Status = 'New');
        insert testCase;

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

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/upload-status';
        req.httpMethod = 'POST';
        req.headers.put('Origin', 'https://example.com');
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'caseId' => testCase.Id,
            'uploadKey' => 'test-key',
            'fileName' => 'completed-file.pdf',
            'formId' => form.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('complete', response.get('status'), 'Status should be complete');
    }

    @isTest
    static void testUploadStatusMissingParams() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/upload-status';
        req.httpMethod = 'POST';
        req.headers.put('Origin', 'https://example.com');
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'caseId' => 'testId'
            // Missing uploadKey, fileName, formId
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing params');
    }

    @isTest
    static void testUploadStatusUnauthorizedOrigin() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'embed-test-form' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/webtocase/v1/upload-status';
        req.httpMethod = 'POST';
        req.headers.put('Origin', 'https://evil.com');
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'caseId' => 'testId',
            'uploadKey' => 'test-key',
            'fileName' => 'test.pdf',
            'formId' => form.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        WebToCaseRestAPI.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(403, res.statusCode, 'Should return 403 for unauthorized origin');
    }

    // ==================== FormAdminController Allowed Domains Test ====================

    @isTest
    static void testSaveFormWithAllowedDomains() {
        Map<String, Object> formData = new Map<String, Object>();
        formData.put('id', null);
        formData.put('formName', 'domains-test-form');
        formData.put('title', 'Domains Test Form');
        formData.put('description', null);
        formData.put('active', true);
        formData.put('enableFileUpload', false);
        formData.put('maxFileSizeMB', 10);
        formData.put('successMessage', null);
        formData.put('enableCaptcha', false);
        formData.put('siteId', null);
        formData.put('allowedDomains', 'test.com\ntest2.com');

        Test.startTest();
        String formId = FormAdminController.saveForm(formData);
        Test.stopTest();

        Form__c savedForm = [SELECT Allowed_Domains__c FROM Form__c WHERE Id = :formId];
        System.assertEquals('test.com\ntest2.com', savedForm.Allowed_Domains__c, 'Allowed domains should be saved');
    }

    @isTest
    static void testGetFormWithFieldsIncludesAllowedDomains() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'embed-test-form' LIMIT 1];

        Test.startTest();
        FormAdminController.FormWrapper wrapper = FormAdminController.getFormWithFields(form.Id);
        Test.stopTest();

        System.assertNotEquals(null, wrapper.allowedDomains, 'Allowed domains should be returned');
        System.assert(wrapper.allowedDomains.contains('example.com'), 'Should contain example.com');
    }
}
