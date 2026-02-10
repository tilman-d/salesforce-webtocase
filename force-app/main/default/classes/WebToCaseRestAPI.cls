/**
 * WebToCaseRestAPI - REST API for embeddable widget
 * Provides endpoints for form configuration and submission with CORS support
 *
 * Endpoints:
 * GET  /webtocase/v1/form/{formName} - Get form configuration + nonce
 * POST /webtocase/v1/submit          - Submit form data
 * POST /webtocase/v1/upload-chunk    - Upload file chunk
 * POST /webtocase/v1/upload-status   - Check async upload assembly status
 */
@RestResource(urlMapping='/webtocase/v1/*')
global without sharing class WebToCaseRestAPI {

    // Allowed CORS headers
    private static final String ALLOWED_HEADERS = 'Content-Type, Accept, Origin';

    // Chunk size for file uploads (matches CaseFormController)
    private static final Integer CHUNK_SIZE = 750000;

    /**
     * Handle GET requests - Form configuration
     */
    @HttpGet
    global static void getFormConfig() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Parse form name from URL path
            String formName = parseFormNameFromPath(req.requestURI);

            if (String.isBlank(formName)) {
                sendErrorResponse(res, 400, 'Form name is required');
                return;
            }

            // Validate origin and set CORS headers
            String origin = req.headers.get('Origin');
            OriginValidationResult originResult = validateOrigin(origin, formName);

            // Always set CORS headers when origin is present so error messages are readable
            if (String.isNotBlank(origin)) {
                setCorsHeaders(res, origin);
            }

            if (!originResult.valid) {
                sendErrorResponse(res, 403, originResult.error);
                return;
            }

            // Get form configuration
            List<Form__c> forms = [
                SELECT Id, Form_Name__c, Title__c, Description__c, Success_Message__c,
                       Enable_File_Upload__c, Max_File_Size_MB__c, Enable_Captcha__c
                FROM Form__c
                WHERE Form_Name__c = :formName AND Active__c = true
                LIMIT 1
            ];

            if (forms.isEmpty()) {
                sendErrorResponse(res, 404, 'Form not found or inactive');
                return;
            }

            Form__c form = forms[0];

            // Get form fields
            List<Form_Field__c> fields = [
                SELECT Id, Field_Label__c, Field_Type__c, Case_Field__c, Required__c, Sort_Order__c
                FROM Form_Field__c
                WHERE Form__c = :form.Id
                ORDER BY Sort_Order__c ASC
            ];

            // Build allowed fields list
            List<String> allowedFields = new List<String>();
            for (Form_Field__c field : fields) {
                allowedFields.add(field.Case_Field__c);
            }

            // Generate nonce
            String nonce = WebToCaseNonceService.generateNonce(form.Id, originResult.canonicalOrigin, allowedFields);

            // Build response
            Map<String, Object> response = new Map<String, Object>();
            response.put('formId', form.Id);
            response.put('formName', form.Form_Name__c);
            response.put('title', form.Title__c);
            response.put('description', form.Description__c);
            response.put('successMessage', form.Success_Message__c);
            response.put('enableFileUpload', form.Enable_File_Upload__c);
            response.put('maxFileSizeMB', form.Max_File_Size_MB__c != null ? form.Max_File_Size_MB__c : 10);
            response.put('enableCaptcha', form.Enable_Captcha__c);
            response.put('nonce', nonce);
            response.put('chunkSize', CHUNK_SIZE);

            // Add captcha config if enabled
            if (form.Enable_Captcha__c == true) {
                reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
                if (settings != null && String.isNotBlank(settings.Site_Key__c)) {
                    response.put('captchaSiteKey', settings.Site_Key__c);
                    response.put('captchaType', String.isNotBlank(settings.Captcha_Type__c) ? settings.Captcha_Type__c : 'V2_Checkbox');
                }
            }

            // Add fields
            List<Map<String, Object>> fieldsList = new List<Map<String, Object>>();
            for (Form_Field__c field : fields) {
                Map<String, Object> fieldMap = new Map<String, Object>();
                fieldMap.put('id', field.Id);
                fieldMap.put('label', field.Field_Label__c);
                fieldMap.put('type', field.Field_Type__c);
                fieldMap.put('caseField', field.Case_Field__c);
                fieldMap.put('required', field.Required__c);
                fieldMap.put('sortOrder', field.Sort_Order__c);
                fieldsList.add(fieldMap);
            }
            response.put('fields', fieldsList);

            sendSuccessResponse(res, response);

        } catch (WebToCaseNonceService.NonceException e) {
            sendErrorResponse(res, 500, e.getMessage());
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            sendErrorResponse(res, 500, 'Internal server error');
        }
    }

    /**
     * Handle POST requests - Form submission and file upload
     */
    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Parse action from URL path
            String action = parseActionFromPath(req.requestURI);

            if (action == 'submit') {
                handleSubmit(req, res);
            } else if (action == 'upload-chunk') {
                handleUploadChunk(req, res);
            } else if (action == 'upload-status') {
                handleUploadStatus(req, res);
            } else {
                sendErrorResponse(res, 400, 'Invalid action: ' + action);
            }

        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            sendErrorResponse(res, 500, 'Internal server error');
        }
    }

    /**
     * Handle form submission
     */
    private static void handleSubmit(RestRequest req, RestResponse res) {
        // Parse request body
        Map<String, Object> body;
        try {
            body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        } catch (Exception e) {
            sendErrorResponse(res, 400, 'Invalid JSON body');
            return;
        }

        String formId = (String) body.get('formId');
        String nonce = (String) body.get('nonce');
        Map<String, Object> fieldValuesRaw = (Map<String, Object>) body.get('fieldValues');
        String fileName = (String) body.get('fileName');
        String fileContent = (String) body.get('fileContent');
        String captchaToken = (String) body.get('captchaToken');

        // Validate required fields
        if (String.isBlank(formId) || String.isBlank(nonce)) {
            sendErrorResponse(res, 400, 'formId and nonce are required');
            return;
        }

        // Validate origin and set CORS headers
        String origin = req.headers.get('Origin');
        OriginValidationResult originResult = validateOriginForFormId(origin, formId);

        // Always set CORS headers when origin is present so error messages are readable
        if (String.isNotBlank(origin)) {
            setCorsHeaders(res, origin);
        }

        if (!originResult.valid) {
            sendErrorResponse(res, 403, originResult.error);
            return;
        }

        // Check rate limit
        WebToCaseRateLimiter.RateLimitResult rateLimitResult =
            WebToCaseRateLimiter.checkAndIncrement(originResult.canonicalOrigin);

        if (!rateLimitResult.allowed) {
            res.statusCode = 429;
            res.headers.put('Retry-After', String.valueOf(rateLimitResult.retryAfterSeconds));
            Map<String, Object> errorResponse = new Map<String, Object>();
            errorResponse.put('success', false);
            errorResponse.put('error', 'Rate limit exceeded. Please try again later.');
            errorResponse.put('retryAfter', rateLimitResult.retryAfterSeconds);
            res.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
            return;
        }

        // Validate and consume nonce (BEFORE any side effects)
        WebToCaseNonceService.NonceData nonceData =
            WebToCaseNonceService.validateAndConsume(nonce, formId, originResult.canonicalOrigin);

        if (nonceData == null) {
            sendErrorResponse(res, 400, 'Invalid or expired nonce. Please refresh and try again.');
            return;
        }

        // Filter field values to only allowed fields
        Map<String, String> fieldValues = new Map<String, String>();
        if (fieldValuesRaw != null) {
            for (String fieldName : fieldValuesRaw.keySet()) {
                if (WebToCaseNonceService.isFieldAllowed(nonceData, fieldName)) {
                    Object val = fieldValuesRaw.get(fieldName);
                    fieldValues.put(fieldName, val != null ? String.valueOf(val) : '');
                }
                // Silently ignore fields not in the allowed list
            }
        }

        // Call existing submit logic
        Map<String, Object> result = CaseFormController.submitForm(
            formId, fieldValues, fileName, fileContent, captchaToken
        );

        sendSuccessResponse(res, result);
    }

    /**
     * Handle file chunk upload
     */
    private static void handleUploadChunk(RestRequest req, RestResponse res) {
        // Parse request body
        Map<String, Object> body;
        try {
            body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        } catch (Exception e) {
            sendErrorResponse(res, 400, 'Invalid JSON body');
            return;
        }

        String caseId = (String) body.get('caseId');
        String fileName = (String) body.get('fileName');
        String chunkData = (String) body.get('chunkData');
        Integer chunkIndex = body.get('chunkIndex') != null ? Integer.valueOf(String.valueOf(body.get('chunkIndex'))) : null;
        Integer totalChunks = body.get('totalChunks') != null ? Integer.valueOf(String.valueOf(body.get('totalChunks'))) : null;
        String uploadKey = (String) body.get('uploadKey');
        String formId = (String) body.get('formId');

        // Validate required fields
        if (String.isBlank(caseId) || String.isBlank(fileName) || String.isBlank(chunkData) ||
            chunkIndex == null || totalChunks == null || String.isBlank(uploadKey) || String.isBlank(formId)) {
            sendErrorResponse(res, 400, 'Missing required parameters for chunk upload');
            return;
        }

        // Validate origin against the form's allowed domains
        String origin = req.headers.get('Origin');
        OriginValidationResult originResult = validateOriginForFormId(origin, formId);

        // Always set CORS headers when origin is present so error messages are readable
        if (String.isNotBlank(origin)) {
            setCorsHeaders(res, origin);
        }

        if (!originResult.valid) {
            sendErrorResponse(res, 403, originResult.error);
            return;
        }

        // Call existing chunk upload logic
        Map<String, Object> result = CaseFormController.uploadFileChunk(
            caseId, fileName, chunkData, chunkIndex, totalChunks, uploadKey
        );

        sendSuccessResponse(res, result);
    }

    /**
     * Handle upload status check (polling for async assembly completion)
     */
    private static void handleUploadStatus(RestRequest req, RestResponse res) {
        // Parse request body
        Map<String, Object> body;
        try {
            body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
        } catch (Exception e) {
            sendErrorResponse(res, 400, 'Invalid JSON body');
            return;
        }

        String caseId = (String) body.get('caseId');
        String uploadKey = (String) body.get('uploadKey');
        String fileName = (String) body.get('fileName');
        String formId = (String) body.get('formId');

        // Validate required fields
        if (String.isBlank(caseId) || String.isBlank(uploadKey) ||
            String.isBlank(fileName) || String.isBlank(formId)) {
            sendErrorResponse(res, 400, 'Missing required parameters for upload status check');
            return;
        }

        // Validate origin against the form's allowed domains
        String origin = req.headers.get('Origin');
        OriginValidationResult originResult = validateOriginForFormId(origin, formId);

        // Always set CORS headers when origin is present so error messages are readable
        if (String.isNotBlank(origin)) {
            setCorsHeaders(res, origin);
        }

        if (!originResult.valid) {
            sendErrorResponse(res, 403, originResult.error);
            return;
        }

        // Call existing status check logic
        Map<String, Object> result = CaseFormController.checkUploadStatus(caseId, uploadKey, fileName);

        sendSuccessResponse(res, result);
    }

    /**
     * Handle DELETE requests for CORS preflight (used as OPTIONS workaround)
     * Note: @HttpOptions is not supported in Apex. CORS preflight should be
     * configured at the Site/Community level in Salesforce Setup.
     * This method exists for completeness but may not be called.
     */
    @HttpDelete
    global static void handleDelete() {
        RestResponse res = RestContext.response;
        // Return 405 Method Not Allowed for DELETE requests
        res.statusCode = 405;
        res.headers.put('Content-Type', 'application/json');
        Map<String, Object> error = new Map<String, Object>();
        error.put('success', false);
        error.put('error', 'DELETE method not supported');
        res.responseBody = Blob.valueOf(JSON.serialize(error));
    }

    // ============ Helper Methods ============

    /**
     * Result of origin validation
     */
    private class OriginValidationResult {
        public Boolean valid;
        public String error;
        public String canonicalOrigin;

        OriginValidationResult(Boolean valid, String error, String canonicalOrigin) {
            this.valid = valid;
            this.error = error;
            this.canonicalOrigin = canonicalOrigin;
        }
    }

    /**
     * Validate origin header against form's allowed domains
     */
    private static OriginValidationResult validateOrigin(String origin, String formName) {
        // Reject null/empty origin
        if (String.isBlank(origin)) {
            return new OriginValidationResult(false, 'Origin header is required', null);
        }

        // Parse and canonicalize origin
        String canonicalOrigin = canonicalizeOrigin(origin);
        if (canonicalOrigin == null) {
            return new OriginValidationResult(false, 'Invalid origin format', null);
        }

        // Get form's allowed domains
        List<Form__c> forms = [
            SELECT Id, Allowed_Domains__c
            FROM Form__c
            WHERE Form_Name__c = :formName AND Active__c = true
            LIMIT 1
        ];

        if (forms.isEmpty()) {
            return new OriginValidationResult(false, 'Form not found', null);
        }

        String allowedDomains = forms[0].Allowed_Domains__c;

        // If no allowed domains configured, external embedding is disabled
        if (String.isBlank(allowedDomains)) {
            return new OriginValidationResult(false, 'External embedding not enabled for this form', null);
        }

        // Check if origin matches any allowed domain
        if (isDomainAllowed(canonicalOrigin, allowedDomains)) {
            return new OriginValidationResult(true, null, canonicalOrigin);
        }

        return new OriginValidationResult(false, 'Origin not allowed', null);
    }

    /**
     * Validate origin for a form ID (used during submission)
     */
    private static OriginValidationResult validateOriginForFormId(String origin, String formId) {
        // Reject null/empty origin
        if (String.isBlank(origin)) {
            return new OriginValidationResult(false, 'Origin header is required', null);
        }

        // Parse and canonicalize origin
        String canonicalOrigin = canonicalizeOrigin(origin);
        if (canonicalOrigin == null) {
            return new OriginValidationResult(false, 'Invalid origin format', null);
        }

        // Get form's allowed domains
        List<Form__c> forms = [
            SELECT Id, Allowed_Domains__c
            FROM Form__c
            WHERE Id = :formId AND Active__c = true
            LIMIT 1
        ];

        if (forms.isEmpty()) {
            return new OriginValidationResult(false, 'Form not found', null);
        }

        String allowedDomains = forms[0].Allowed_Domains__c;

        // If no allowed domains configured, external embedding is disabled
        if (String.isBlank(allowedDomains)) {
            return new OriginValidationResult(false, 'External embedding not enabled for this form', null);
        }

        // Check if origin matches any allowed domain
        if (isDomainAllowed(canonicalOrigin, allowedDomains)) {
            return new OriginValidationResult(true, null, canonicalOrigin);
        }

        return new OriginValidationResult(false, 'Origin not allowed', null);
    }

    /**
     * Canonicalize an origin URL to just the domain
     * Returns null if invalid
     */
    private static String canonicalizeOrigin(String origin) {
        if (String.isBlank(origin)) {
            return null;
        }

        try {
            // Lowercase
            origin = origin.toLowerCase().trim();

            // Must start with http:// or https://
            if (!origin.startsWith('http://') && !origin.startsWith('https://')) {
                return null;
            }

            // Remove protocol
            String withoutProtocol = origin.substringAfter('://');

            // Remove path/query if present
            if (withoutProtocol.contains('/')) {
                withoutProtocol = withoutProtocol.substringBefore('/');
            }

            // Remove port if present (unless non-standard)
            String domain = withoutProtocol;
            if (domain.contains(':')) {
                String port = domain.substringAfter(':');
                domain = domain.substringBefore(':');
                // Keep port in canonical form only for non-standard ports
                if (origin.startsWith('https://') && port != '443') {
                    domain = domain + ':' + port;
                } else if (origin.startsWith('http://') && port != '80') {
                    domain = domain + ':' + port;
                }
            }

            // Reject if empty
            if (String.isBlank(domain)) {
                return null;
            }

            // Reject localhost in production (allow in sandbox/dev)
            // Note: Uncomment in production
            // if (domain == 'localhost' || domain.startsWith('localhost:') ||
            //     domain == '127.0.0.1' || domain.startsWith('127.0.0.1:')) {
            //     return null;
            // }

            // Reject IP addresses (simple check)
            if (isIPAddress(domain)) {
                return null;
            }

            // Reject trailing dots
            if (domain.endsWith('.')) {
                return null;
            }

            // Reject userinfo (e.g., user:pass@domain)
            if (domain.contains('@')) {
                return null;
            }

            return domain;

        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Simple check if a string looks like an IP address
     */
    private static Boolean isIPAddress(String domain) {
        // Check for IPv4
        Pattern ipv4Pattern = Pattern.compile('^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}(:\\d+)?$');
        if (ipv4Pattern.matcher(domain).matches()) {
            return true;
        }

        // Check for IPv6 (starts with [ )
        if (domain.startsWith('[')) {
            return true;
        }

        return false;
    }

    /**
     * Check if a domain is in the allowed list
     * Supports exact match, www-prefix matching, and port stripping
     */
    private static Boolean isDomainAllowed(String canonicalOrigin, String allowedDomains) {
        // Parse allowed domains (newline-separated)
        List<String> domains = allowedDomains.split('\n');

        // Strip www. from origin for comparison
        String originBare = canonicalOrigin.startsWith('www.') ? canonicalOrigin.substringAfter('www.') : canonicalOrigin;

        for (String allowedDomain : domains) {
            allowedDomain = allowedDomain.trim().toLowerCase();

            // Skip empty lines
            if (String.isBlank(allowedDomain)) {
                continue;
            }

            // Strip www. from allowed domain for comparison
            String allowedBare = allowedDomain.startsWith('www.') ? allowedDomain.substringAfter('www.') : allowedDomain;

            // Match: bare domains (ignoring www on both sides)
            if (originBare == allowedBare) {
                return true;
            }

            // Also check without port if origin has port
            if (originBare.contains(':')) {
                String domainOnly = originBare.substringBefore(':');
                if (domainOnly == allowedBare) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Parse form name from URL path
     * Expected format: /webtocase/v1/form/{formName}
     */
    private static String parseFormNameFromPath(String uri) {
        if (String.isBlank(uri)) {
            return null;
        }

        // Remove leading/trailing slashes and normalize
        uri = uri.trim();
        if (uri.startsWith('/services/apexrest')) {
            uri = uri.substringAfter('/services/apexrest');
        }

        // Expected: /webtocase/v1/form/{formName}
        Pattern p = Pattern.compile('/webtocase/v1/form/([^/]+)');
        Matcher m = p.matcher(uri);

        if (m.find()) {
            return EncodingUtil.urlDecode(m.group(1), 'UTF-8');
        }

        return null;
    }

    /**
     * Parse action from URL path
     * Expected format: /webtocase/v1/{action}
     */
    private static String parseActionFromPath(String uri) {
        if (String.isBlank(uri)) {
            return null;
        }

        uri = uri.trim();
        if (uri.startsWith('/services/apexrest')) {
            uri = uri.substringAfter('/services/apexrest');
        }

        // Expected: /webtocase/v1/{action}
        Pattern p = Pattern.compile('/webtocase/v1/([^/]+)');
        Matcher m = p.matcher(uri);

        if (m.find()) {
            return m.group(1).toLowerCase();
        }

        return null;
    }

    /**
     * Set CORS headers on response
     */
    private static void setCorsHeaders(RestResponse res, String origin) {
        if (String.isNotBlank(origin)) {
            res.headers.put('Access-Control-Allow-Origin', origin);
        }
        res.headers.put('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.headers.put('Access-Control-Allow-Headers', ALLOWED_HEADERS);
        res.headers.put('Access-Control-Max-Age', '86400'); // 24 hours
        res.headers.put('Vary', 'Origin');
    }

    /**
     * Send success response
     */
    private static void sendSuccessResponse(RestResponse res, Map<String, Object> data) {
        res.statusCode = 200;
        res.headers.put('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(data));
    }

    /**
     * Send error response
     */
    private static void sendErrorResponse(RestResponse res, Integer statusCode, String message) {
        res.statusCode = statusCode;
        res.headers.put('Content-Type', 'application/json');
        Map<String, Object> error = new Map<String, Object>();
        error.put('success', false);
        error.put('error', message);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
    }
}
