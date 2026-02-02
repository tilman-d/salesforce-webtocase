/**
 * CaseFormController - Main controller for the public web form
 * Handles form rendering and case submission with file attachments
 * Uses 'without sharing' to allow guest users to create Cases
 */
global without sharing class CaseFormController {

    // Form configuration loaded from URL parameter
    public Form__c form { get; set; }

    // Form fields to render
    public List<Form_Field__c> fields { get; set; }

    // Form name from URL parameter
    public String formName { get; set; }

    // Preview mode (bypasses Active check for admin testing)
    public Boolean isPreviewMode { get; set; }

    // Chunk size for file uploads (750KB raw = ~1MB Base64, safely under VF Remoting limits)
    private static final Integer CHUNK_SIZE = 750000;

    /**
     * Constructor - loads form based on URL parameter
     */
    public CaseFormController() {
        // Support both 'name' and 'form' parameters for backwards compatibility
        formName = ApexPages.currentPage().getParameters().get('name');
        if (String.isBlank(formName)) {
            formName = ApexPages.currentPage().getParameters().get('form');
        }
        // Check for preview mode
        isPreviewMode = ApexPages.currentPage().getParameters().get('preview') == 'true';
        loadForm();
    }

    /**
     * Load the form configuration and fields
     */
    private void loadForm() {
        if (String.isBlank(formName)) {
            return;
        }

        try {
            // In preview mode, allow inactive forms for admin testing
            String query = 'SELECT Id, Form_Name__c, Title__c, Description__c, ' +
                          'Success_Message__c, Active__c, Enable_File_Upload__c, ' +
                          'Max_File_Size_MB__c, Enable_Captcha__c FROM Form__c WHERE Form_Name__c = :formName';
            if (!isPreviewMode) {
                query += ' AND Active__c = true';
            }
            query += ' LIMIT 1';

            List<Form__c> forms = Database.query(query);

            if (!forms.isEmpty()) {
                form = forms[0];
                fields = [
                    SELECT Id, Field_Label__c, Field_Type__c, Case_Field__c,
                           Required__c, Sort_Order__c
                    FROM Form_Field__c
                    WHERE Form__c = :form.Id
                    ORDER BY Sort_Order__c ASC
                ];
            }
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
        }
    }

    /**
     * Get the captcha site key from custom settings
     */
    public String getCaptchaSiteKey() {
        reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
        if (settings != null && String.isNotBlank(settings.Site_Key__c)) {
            return settings.Site_Key__c;
        }
        return '';
    }

    /**
     * Get the captcha type from custom settings
     * Defaults to V2_Checkbox for backwards compatibility
     */
    public String getCaptchaType() {
        reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
        if (settings != null && String.isNotBlank(settings.Captcha_Type__c)) {
            return settings.Captcha_Type__c;
        }
        return 'V2_Checkbox';
    }

    /**
     * Check if captcha is enabled for this form
     */
    public Boolean getCaptchaEnabled() {
        if (form != null && form.Enable_Captcha__c == true) {
            String siteKey = getCaptchaSiteKey();
            return String.isNotBlank(siteKey);
        }
        return false;
    }

    /**
     * Submit the form and create a Case with optional file attachment
     * @param formId ID of the form being submitted
     * @param fieldValues Map of Case field API names to values
     * @param fileName Name of the attached file (empty if no file)
     * @param fileContent Base64 encoded file content (empty if no file)
     * @param captchaToken reCAPTCHA token for verification (empty if captcha not enabled)
     * @return Map containing success status, case number or error message
     */
    @RemoteAction
    global static Map<String, Object> submitForm(String formId, Map<String, String> fieldValues,
                                                  String fileName, String fileContent, String captchaToken) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Validate form exists and is active
            List<Form__c> forms = [
                SELECT Id, Form_Name__c, Enable_File_Upload__c, Max_File_Size_MB__c, Enable_Captcha__c
                FROM Form__c
                WHERE Id = :formId AND Active__c = true
                LIMIT 1
            ];

            if (forms.isEmpty()) {
                result.put('success', false);
                result.put('error', 'Form not found or inactive.');
                return result;
            }

            Form__c form = forms[0];

            // Verify reCAPTCHA if enabled
            if (form.Enable_Captcha__c == true) {
                reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
                if (settings != null && String.isNotBlank(settings.Secret_Key__c)) {
                    if (String.isBlank(captchaToken)) {
                        result.put('success', false);
                        result.put('error', 'Please complete the CAPTCHA verification.');
                        return result;
                    }

                    // Get captcha type and threshold
                    String captchaType = String.isNotBlank(settings.Captcha_Type__c) ? settings.Captcha_Type__c : 'V2_Checkbox';
                    Decimal scoreThreshold = settings.Score_Threshold__c != null ? settings.Score_Threshold__c : 0.3;

                    // Verify with Google
                    Map<String, Object> captchaResult = verifyCaptchaWithDetails(captchaToken, settings.Secret_Key__c);
                    Boolean captchaSuccess = captchaResult.get('success') == true;

                    if (!captchaSuccess) {
                        result.put('success', false);
                        result.put('error', 'CAPTCHA verification failed. Please try again.');
                        return result;
                    }

                    // Additional v3 validation
                    if (captchaType == 'V3_Score') {
                        // Validate action matches expected (prevents replay attacks)
                        String action = (String) captchaResult.get('action');
                        if (action != 'submit') {
                            ErrorLogger.log('reCAPTCHA v3 action mismatch', 'Expected: submit, Got: ' + action, formId);
                            result.put('success', false);
                            result.put('error', 'Security verification failed.');
                            return result;
                        }

                        // Check score threshold
                        Decimal score = captchaResult.get('score') != null ? (Decimal) captchaResult.get('score') : 0;
                        if (score < scoreThreshold) {
                            // Log for admin review (but don't log the raw token!)
                            ErrorLogger.log('reCAPTCHA v3 score below threshold',
                                'Score: ' + score + ', Threshold: ' + scoreThreshold, formId);
                            result.put('success', false);
                            result.put('error', 'Submission blocked for security reasons. Please try again or contact support.');
                            return result;
                        }
                    }
                }
            }

            // Create the Case
            Case newCase = new Case();
            newCase.Origin = 'Web Form';
            newCase.Status = 'New';

            // Map field values to Case fields
            if (fieldValues != null) {
                for (String caseField : fieldValues.keySet()) {
                    String value = fieldValues.get(caseField);
                    if (String.isNotBlank(value)) {
                        if (caseField == 'Subject') {
                            newCase.Subject = value;
                        } else if (caseField == 'Description') {
                            newCase.Description = value;
                        } else if (caseField == 'SuppliedName') {
                            newCase.SuppliedName = value;
                        } else if (caseField == 'SuppliedEmail') {
                            newCase.SuppliedEmail = value;
                        } else if (caseField == 'SuppliedPhone') {
                            newCase.SuppliedPhone = value;
                        } else if (caseField == 'SuppliedCompany') {
                            newCase.SuppliedCompany = value;
                        }
                    }
                }
            }

            insert newCase;

            // Attach file if provided and file upload is enabled
            if (form.Enable_File_Upload__c && String.isNotBlank(fileName) && String.isNotBlank(fileContent)) {
                // Validate file size
                Integer maxSizeBytes = (form.Max_File_Size_MB__c != null ?
                                        (Integer)form.Max_File_Size_MB__c : 10) * 1024 * 1024;
                Blob fileData = EncodingUtil.base64Decode(fileContent);

                if (fileData.size() > maxSizeBytes) {
                    // Case is already created, but we'll note the file was too large
                    result.put('success', true);
                    result.put('caseNumber', [SELECT CaseNumber FROM Case WHERE Id = :newCase.Id].CaseNumber);
                    result.put('warning', 'File was too large and was not attached.');
                    return result;
                }

                // Create ContentVersion (file)
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = fileData;
                insert cv;

                // Get the ContentDocumentId
                ContentVersion insertedCv = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cv.Id
                ];

                // Link file to Case
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = insertedCv.ContentDocumentId;
                cdl.LinkedEntityId = newCase.Id;
                cdl.ShareType = 'V'; // Viewer permission
                cdl.Visibility = 'AllUsers';
                insert cdl;
            }

            // Get the Case Number for success message
            Case createdCase = [SELECT CaseNumber FROM Case WHERE Id = :newCase.Id];

            result.put('success', true);
            result.put('caseNumber', createdCase.CaseNumber);
            result.put('caseId', newCase.Id); // Return caseId for chunked file uploads

        } catch (Exception e) {
            ErrorLogger.logException(e, formId);
            result.put('success', false);
            result.put('error', 'An error occurred while submitting your request. Please try again.');
            // In debug mode, we could return more details
            // result.put('debugError', e.getMessage());
        }

        return result;
    }

    /**
     * Upload a file chunk for large file uploads (>1MB)
     * Files are split into chunks on the client side and reassembled here
     * @param caseId ID of the Case to attach the file to
     * @param fileName Original file name
     * @param chunkData Base64 encoded chunk data
     * @param chunkIndex 0-based index of this chunk
     * @param totalChunks Total number of chunks for this file
     * @param uploadKey Unique key for this upload session (UUID generated client-side)
     * @return Map containing success status and any error message
     */
    @RemoteAction
    global static Map<String, Object> uploadFileChunk(String caseId, String fileName,
                                                       String chunkData, Integer chunkIndex,
                                                       Integer totalChunks, String uploadKey) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Validate inputs
            if (String.isBlank(caseId) || String.isBlank(fileName) ||
                String.isBlank(chunkData) || String.isBlank(uploadKey)) {
                result.put('success', false);
                result.put('error', 'Missing required parameters for file upload.');
                return result;
            }

            // Verify the Case exists
            List<Case> cases = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
            if (cases.isEmpty()) {
                result.put('success', false);
                result.put('error', 'Case not found.');
                return result;
            }

            // Store chunk as a ContentVersion with special naming
            // Format: __chunk__{uploadKey}__{chunkIndex}__{totalChunks}__{fileName}
            // Link directly to Case via FirstPublishLocationId to enable Guest User access
            String chunkTitle = '__chunk__' + uploadKey + '__' + chunkIndex + '__' + totalChunks + '__' + fileName;

            ContentVersion cv = new ContentVersion();
            cv.Title = chunkTitle;
            cv.PathOnClient = chunkTitle + '.tmp';
            cv.VersionData = EncodingUtil.base64Decode(chunkData);
            cv.FirstPublishLocationId = caseId; // Link to Case for Guest User sharing
            insert cv;

            // Check if this is the last chunk
            if (chunkIndex == totalChunks - 1) {
                // Query chunk IDs first (without loading blob data into heap)
                List<ContentDocumentLink> links = [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :caseId
                ];

                Set<Id> docIds = new Set<Id>();
                for (ContentDocumentLink link : links) {
                    docIds.add(link.ContentDocumentId);
                }

                // Query chunk metadata only (no VersionData)
                List<ContentVersion> chunkMeta = [
                    SELECT Id, Title, ContentDocumentId
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docIds
                      AND Title LIKE :('__chunk__' + uploadKey + '__%')
                    ORDER BY Title ASC
                ];

                // Verify we have all chunks
                if (chunkMeta.size() != totalChunks) {
                    result.put('success', false);
                    result.put('error', 'Missing file chunks. Expected ' + totalChunks + ', found ' + chunkMeta.size());
                    return result;
                }

                // Build a map of chunk index to ContentVersion Id
                Map<Integer, Id> chunkIdMap = new Map<Integer, Id>();
                Set<Id> chunkDocIdsToDelete = new Set<Id>();

                for (ContentVersion chunk : chunkMeta) {
                    // Parse chunk index from title: __chunk__{uploadKey}__{chunkIndex}__{totalChunks}__{fileName}
                    String[] parts = chunk.Title.split('__');
                    if (parts.size() >= 4) {
                        Integer idx = Integer.valueOf(parts[3]);
                        chunkIdMap.put(idx, chunk.Id);
                        chunkDocIdsToDelete.add(chunk.ContentDocumentId);
                    }
                }

                // Assemble the complete file by querying each chunk's data one at a time
                // This minimizes heap usage by not holding all chunks in memory simultaneously
                String combinedBase64 = '';
                for (Integer i = 0; i < totalChunks; i++) {
                    if (!chunkIdMap.containsKey(i)) {
                        result.put('success', false);
                        result.put('error', 'Missing chunk ' + i);
                        return result;
                    }

                    // Query single chunk's data
                    ContentVersion chunk = [
                        SELECT VersionData
                        FROM ContentVersion
                        WHERE Id = :chunkIdMap.get(i)
                        LIMIT 1
                    ];

                    // Append to combined base64 and release chunk reference
                    combinedBase64 += EncodingUtil.base64Encode(chunk.VersionData);
                }

                // Decode the complete file
                Blob completeFile = EncodingUtil.base64Decode(combinedBase64);
                combinedBase64 = null; // Release string memory

                // Create the final ContentVersion
                ContentVersion finalCv = new ContentVersion();
                finalCv.Title = fileName;
                finalCv.PathOnClient = fileName;
                finalCv.VersionData = completeFile;
                insert finalCv;

                // Get the ContentDocumentId
                ContentVersion insertedCv = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :finalCv.Id
                ];

                // Link file to Case
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = insertedCv.ContentDocumentId;
                cdl.LinkedEntityId = caseId;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                insert cdl;

                // Clean up chunk files - use the doc IDs we collected earlier
                // Wrap in try-catch so cleanup failures don't affect success response
                try {
                    if (!chunkDocIdsToDelete.isEmpty()) {
                        delete [SELECT Id FROM ContentDocument WHERE Id IN :chunkDocIdsToDelete];
                    }
                } catch (Exception cleanupEx) {
                    // Log but don't fail - the file was successfully uploaded
                    System.debug('Chunk cleanup failed: ' + cleanupEx.getMessage());
                }

                result.put('success', true);
                result.put('complete', true);
                result.put('message', 'File uploaded successfully.');
            } else {
                // Not the last chunk, just confirm receipt
                result.put('success', true);
                result.put('complete', false);
                result.put('chunkReceived', chunkIndex);
            }

        } catch (Exception e) {
            ErrorLogger.logException(e, caseId);
            result.put('success', false);
            result.put('error', 'Error uploading file chunk: ' + e.getMessage());
        }

        return result;
    }

    /**
     * Get the chunk size for file uploads (exposed for JavaScript)
     * @return Chunk size in bytes
     */
    @RemoteAction
    global static Integer getChunkSize() {
        return CHUNK_SIZE;
    }

    /**
     * Verify reCAPTCHA token with Google's API and return full response details
     * Needed for v3 score-based verification
     * @param token The reCAPTCHA response token from the client
     * @param secretKey The secret key from reCAPTCHA settings
     * @return Map with success, score (for v3), action (for v3), and error-codes
     */
    private static Map<String, Object> verifyCaptchaWithDetails(String token, String secretKey) {
        Map<String, Object> resultMap = new Map<String, Object>();
        resultMap.put('success', false);

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://www.google.com/recaptcha/api/siteverify');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('secret=' + EncodingUtil.urlEncode(secretKey, 'UTF-8') +
                       '&response=' + EncodingUtil.urlEncode(token, 'UTF-8'));
            req.setTimeout(10000); // 10 second timeout

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                resultMap.put('success', responseMap.get('success') == true);

                // For v3, extract score and action
                if (responseMap.containsKey('score')) {
                    resultMap.put('score', responseMap.get('score'));
                }
                if (responseMap.containsKey('action')) {
                    resultMap.put('action', responseMap.get('action'));
                }
                if (responseMap.containsKey('error-codes')) {
                    resultMap.put('error-codes', responseMap.get('error-codes'));
                }
            } else {
                ErrorLogger.log('reCAPTCHA verification HTTP error: ' + res.getStatusCode(), res.getBody());
            }
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
        }

        return resultMap;
    }

    /**
     * Verify reCAPTCHA token with Google's API (legacy method for backwards compatibility)
     * @param token The reCAPTCHA response token from the client
     * @param secretKey The secret key from reCAPTCHA settings
     * @return true if verification successful, false otherwise
     */
    private static Boolean verifyCaptcha(String token, String secretKey) {
        Map<String, Object> result = verifyCaptchaWithDetails(token, secretKey);
        return result.get('success') == true;
    }
}
