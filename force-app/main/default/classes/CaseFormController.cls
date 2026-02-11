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

    // Embed mode (for iframe embedding on external sites)
    public Boolean isEmbedMode { get; set; }

    // Chunk size for file uploads (750KB raw = ~1MB Base64, safely under VF Remoting limits)
    // IMPORTANT: CHUNK_SIZE must remain divisible by 3 (750000/3=250000) to ensure
    // intermediate base64 chunks have no padding. Only the last chunk may have padding.
    private static final Integer CHUNK_SIZE = 750000;

    // Threshold for async assembly: files with more than this many chunks
    // use Queueable (12MB heap) instead of synchronous assembly (6MB heap).
    // 3 chunks * 750KB = 2.25MB max for synchronous path.
    private static final Integer SYNC_CHUNK_LIMIT = 3;

    // Test-visible flag to simulate CRUD denial in tests
    @TestVisible private static Boolean testDenyCrud = false;

    /**
     * Custom exception for security/CRUD violations
     */
    public class SecurityException extends Exception {}

    /**
     * Assert that the running user has create access to the given SObject type
     */
    private static void assertCreateable(Schema.SObjectType sot, String label) {
        if (Test.isRunningTest() && testDenyCrud) {
            throw new SecurityException('Insufficient permissions to create ' + label);
        }
        if (!sot.getDescribe().isCreateable()) {
            throw new SecurityException('Insufficient permissions to create ' + label);
        }
    }

    /**
     * Assert that the running user has read access to the given SObject type
     */
    private static void assertAccessible(Schema.SObjectType sot, String label) {
        if (Test.isRunningTest() && testDenyCrud) {
            throw new SecurityException('Insufficient permissions to read ' + label);
        }
        if (!sot.getDescribe().isAccessible()) {
            throw new SecurityException('Insufficient permissions to read ' + label);
        }
    }

    /**
     * Assert that the running user has delete access to the given SObject type
     */
    private static void assertDeletable(Schema.SObjectType sot, String label) {
        if (Test.isRunningTest() && testDenyCrud) {
            throw new SecurityException('Insufficient permissions to delete ' + label);
        }
        if (!sot.getDescribe().isDeletable()) {
            throw new SecurityException('Insufficient permissions to delete ' + label);
        }
    }

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
        isPreviewMode = ApexPages.currentPage().getParameters().get('preview') == 'true'
                        && UserInfo.getUserType() != 'Guest';
        // Check for embed mode
        isEmbedMode = ApexPages.currentPage().getParameters().get('embed') == '1';
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
            // CRUD checks for form configuration queries
            assertAccessible(Form__c.SObjectType, 'Form__c');
            assertAccessible(Form_Field__c.SObjectType, 'Form_Field__c');

            // In preview mode, allow inactive forms for admin testing
            List<Form__c> forms;
            if (isPreviewMode) {
                forms = [
                    SELECT Id, Form_Name__c, Title__c, Description__c,
                           Success_Message__c, Active__c, Enable_File_Upload__c,
                           Max_File_Size_MB__c, Enable_Captcha__c
                    FROM Form__c
                    WHERE Form_Name__c = :formName
                    LIMIT 1
                ];
            } else {
                forms = [
                    SELECT Id, Form_Name__c, Title__c, Description__c,
                           Success_Message__c, Active__c, Enable_File_Upload__c,
                           Max_File_Size_MB__c, Enable_Captcha__c
                    FROM Form__c
                    WHERE Form_Name__c = :formName AND Active__c = true
                    LIMIT 1
                ];
            }

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
            // CRUD checks
            assertAccessible(Form__c.SObjectType, 'Form__c');
            assertAccessible(Case.SObjectType, 'Case');
            assertCreateable(Case.SObjectType, 'Case');

            // Validate form exists and is active
            List<Form__c> forms = [
                SELECT Id, Form_Name__c, Enable_File_Upload__c, Max_File_Size_MB__c, Enable_Captcha__c,
                       Default_Case_Values__c
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

            // Create the Case with hardcoded fallbacks
            Case newCase = new Case();
            newCase.Origin = 'Web Form';
            newCase.Status = 'New';

            // Apply JSON defaults from form config (overrides hardcoded fallbacks)
            // Security note: without sharing + no FLS check is intentional and consistent
            // with the existing pattern for user-supplied fields (Guest User context).
            Boolean defaultsApplied = false;
            if (String.isNotBlank(form.Default_Case_Values__c)) {
                try {
                    Object parsed = JSON.deserializeUntyped(form.Default_Case_Values__c);
                    if (parsed instanceof Map<String, Object>) {
                        Map<String, Object> defaults = (Map<String, Object>) parsed;
                        for (String fieldName : defaults.keySet()) {
                            if (!CaseDefaultFieldConfig.ALLOWED_FIELDS.contains(fieldName)) {
                                continue;
                            }
                            Object rawVal = defaults.get(fieldName);
                            String strVal = String.valueOf(rawVal);
                            if (String.isBlank(strVal) || strVal == 'null') {
                                continue;
                            }
                            newCase.put(fieldName, strVal);
                            defaultsApplied = true;
                        }
                    }
                } catch (Exception jsonEx) {
                    ErrorLogger.log('Invalid Default_Case_Values__c JSON on form ' + formId +
                        '. Value: ' + form.Default_Case_Values__c,
                        jsonEx.getMessage(), formId);
                }
            }

            // Map user-supplied field values to Case fields.
            // Precedence: hardcoded fallbacks (Origin/Status) -> JSON defaults override -> user fields override.
            // In practice, user fields (Subject, Description, Supplied*) and default fields
            // (Priority, Status, Origin, Type, Reason) are disjoint sets, so no conflict.
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

            // FLS enforcement: strip inaccessible fields before Case insert
            SObjectAccessDecision caseDecision = Security.stripInaccessible(
                AccessType.CREATABLE, new List<Case>{ newCase }
            );
            newCase = (Case) caseDecision.getRecords()[0];

            // Insert with DML retry: if defaults cause a DML failure (e.g., invalid
            // picklist value), build a fresh Case without defaults and retry once.
            // This ensures stale/invalid picklist values never block case creation.
            try {
                insert newCase;
            } catch (DmlException dmlEx) {
                if (defaultsApplied) {
                    ErrorLogger.log('DML failed with defaults, retrying without. Defaults: ' +
                        form.Default_Case_Values__c, dmlEx.getMessage(), formId);
                    // Build a fresh Case with only hardcoded fallbacks + user fields
                    Case retryCase = new Case();
                    retryCase.Origin = 'Web Form';
                    retryCase.Status = 'New';
                    if (fieldValues != null) {
                        for (String cf : fieldValues.keySet()) {
                            String v = fieldValues.get(cf);
                            if (String.isNotBlank(v)) {
                                if (cf == 'Subject') retryCase.Subject = v;
                                else if (cf == 'Description') retryCase.Description = v;
                                else if (cf == 'SuppliedName') retryCase.SuppliedName = v;
                                else if (cf == 'SuppliedEmail') retryCase.SuppliedEmail = v;
                                else if (cf == 'SuppliedPhone') retryCase.SuppliedPhone = v;
                                else if (cf == 'SuppliedCompany') retryCase.SuppliedCompany = v;
                            }
                        }
                    }
                    // FLS enforcement on retry Case
                    SObjectAccessDecision retryDecision = Security.stripInaccessible(
                        AccessType.CREATABLE, new List<Case>{ retryCase }
                    );
                    retryCase = (Case) retryDecision.getRecords()[0];
                    insert retryCase;
                    newCase = retryCase;
                } else {
                    throw dmlEx;
                }
            }

            // Authorize this Case for chunked file uploads (only if file upload is enabled)
            if (form.Enable_File_Upload__c) {
                WebToCaseNonceService.authorizeCaseForUpload(newCase.Id);
            }

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

                // CRUD checks for file attachment (object-level only; no stripInaccessible
                // on ContentVersion — required fields like VersionData would be stripped)
                assertAccessible(ContentVersion.SObjectType, 'ContentVersion');
                assertCreateable(ContentVersion.SObjectType, 'ContentVersion');
                assertCreateable(ContentDocumentLink.SObjectType, 'ContentDocumentLink');

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

        } catch (SecurityException se) {
            ErrorLogger.log('CRUD/FLS violation in submitForm: ' + se.getMessage(), se.getStackTraceString(), formId);
            result.put('success', false);
            result.put('error', 'Insufficient permissions. Please contact your administrator.');
        } catch (Exception e) {
            ErrorLogger.logException(e, formId);
            result.put('success', false);
            result.put('error', 'An error occurred while submitting your request. Please try again.');
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

            // Validate chunkIndex bounds
            if (chunkIndex == null || totalChunks == null || chunkIndex < 0 || chunkIndex >= totalChunks || totalChunks < 1) {
                result.put('success', false);
                result.put('error', 'Invalid chunk index or total chunks.');
                return result;
            }

            // CRUD checks for chunk upload
            assertAccessible(Case.SObjectType, 'Case');
            assertCreateable(ContentVersion.SObjectType, 'ContentVersion');

            // Validate individual chunk size (prevent oversized chunks that bypass file size estimation)
            // Base64 encodes 3 bytes into 4 chars, so CHUNK_SIZE bytes = ceil(CHUNK_SIZE/3)*4 base64 chars
            // Allow 10% margin for padding: max base64 length = CHUNK_SIZE * 4/3 + 100
            Integer maxBase64Length = (CHUNK_SIZE * 4 / 3) + 100;
            if (chunkData.length() > maxBase64Length) {
                result.put('success', false);
                result.put('error', 'Chunk data exceeds maximum allowed size.');
                return result;
            }

            // Sanitize uploadKey: strip any double-underscores to prevent title parsing issues
            // The chunk title format uses __ as delimiter, so uploadKey must not contain __
            uploadKey = uploadKey.replace('__', '-');

            // Verify the Case exists
            List<Case> cases = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
            if (cases.isEmpty()) {
                result.put('success', false);
                result.put('error', 'Case not found.');
                return result;
            }

            // IDOR protection: verify this Case was created through submitForm
            if (!WebToCaseNonceService.isCaseAuthorizedForUpload(caseId)) {
                result.put('success', false);
                result.put('error', 'Upload not authorized for this case.');
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
                // Server-side file size validation before assembly/enqueue
                // Estimate total file size: totalChunks * CHUNK_SIZE (last chunk may be smaller but this is a safe upper bound)
                Long estimatedFileSize = (Long)totalChunks * CHUNK_SIZE;

                // Use a 4MB hard cap (the technical limit of async assembly with 12MB Queueable heap)
                Long maxAllowedBytes = 4L * 1024 * 1024;
                if (estimatedFileSize > maxAllowedBytes) {
                    result.put('success', false);
                    result.put('error', 'File exceeds the maximum allowed size of 4MB.');
                    return result;
                }

                // Async path: files with more than SYNC_CHUNK_LIMIT chunks use Queueable
                if (totalChunks > SYNC_CHUNK_LIMIT) {
                    // Enqueue async assembly job
                    System.enqueueJob(new FileAssemblyQueueable(caseId, uploadKey, fileName, totalChunks));

                    result.put('success', true);
                    result.put('complete', false);
                    result.put('processing', true);
                    result.put('uploadKey', uploadKey);
                    result.put('message', 'File is being processed.');
                } else {
                    // Synchronous path for small files (<=3 chunks, <=2.25MB)
                    assembleSynchronous(caseId, uploadKey, fileName, totalChunks, result);
                }
            } else {
                // Not the last chunk, just confirm receipt
                result.put('success', true);
                result.put('complete', false);
                result.put('chunkReceived', chunkIndex);
            }

        } catch (SecurityException se) {
            ErrorLogger.log('CRUD/FLS violation in uploadFileChunk: ' + se.getMessage(), se.getStackTraceString(), caseId);
            result.put('success', false);
            result.put('error', 'Insufficient permissions. Please contact your administrator.');
        } catch (Exception e) {
            ErrorLogger.logException(e, caseId);
            result.put('success', false);
            result.put('error', 'Error uploading file chunk. Please try again.');
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
     * Assemble chunks synchronously (used for files with <= SYNC_CHUNK_LIMIT chunks)
     * Extracted from uploadFileChunk to keep the method manageable.
     */
    private static void assembleSynchronous(String caseId, String uploadKey, String fileName,
                                             Integer totalChunks, Map<String, Object> result) {
        // CRUD checks for assembly operations
        assertAccessible(ContentDocumentLink.SObjectType, 'ContentDocumentLink');
        assertAccessible(ContentVersion.SObjectType, 'ContentVersion');
        assertCreateable(ContentVersion.SObjectType, 'ContentVersion');
        assertCreateable(ContentDocumentLink.SObjectType, 'ContentDocumentLink');
        assertDeletable(ContentDocument.SObjectType, 'ContentDocument');

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
        String chunkPattern = '__chunk__' + uploadKey + '__%';
        List<ContentVersion> chunkMeta = [
            SELECT Id, Title, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Title LIKE :chunkPattern
            ORDER BY Title ASC
        ];

        // Verify we have all chunks
        if (chunkMeta.size() != totalChunks) {
            result.put('success', false);
            result.put('error', 'Missing file chunks. Expected ' + totalChunks + ', found ' + chunkMeta.size());
            return;
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
        String combinedBase64 = '';
        for (Integer i = 0; i < totalChunks; i++) {
            if (!chunkIdMap.containsKey(i)) {
                result.put('success', false);
                result.put('error', 'Missing chunk ' + i);
                return;
            }

            ContentVersion chunk = [
                SELECT VersionData
                FROM ContentVersion
                WHERE Id = :chunkIdMap.get(i)
                LIMIT 1
            ];

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

        // Clean up chunk files
        try {
            if (!chunkDocIdsToDelete.isEmpty()) {
                delete [SELECT Id FROM ContentDocument WHERE Id IN :chunkDocIdsToDelete];
            }
        } catch (Exception cleanupEx) {
            System.debug('Chunk cleanup failed: ' + cleanupEx.getMessage());
        }

        result.put('success', true);
        result.put('complete', true);
        result.put('message', 'File uploaded successfully.');
    }

    /**
     * Check the status of an async file upload
     * Called by client-side polling after Queueable is enqueued
     * @param caseId ID of the Case
     * @param uploadKey Unique key for the upload session
     * @param fileName Expected final file name
     * @return Map with status ('complete', 'processing', or 'error') and optional error message
     */
    @RemoteAction
    global static Map<String, Object> checkUploadStatus(String caseId, String uploadKey, String fileName) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // CRUD checks for status queries
            assertAccessible(ContentDocumentLink.SObjectType, 'ContentDocumentLink');
            assertAccessible(ContentVersion.SObjectType, 'ContentVersion');
            assertAccessible(Error_Log__c.SObjectType, 'Error_Log__c');

            // IDOR check: ensure this Case was created through submitForm
            if (!WebToCaseNonceService.isCaseAuthorizedForUpload(caseId)) {
                result.put('status', 'error');
                result.put('error', 'Upload not authorized for this case.');
                return result;
            }

            // Query ContentDocumentLinks for this Case
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
            ];

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink link : links) {
                docIds.add(link.ContentDocumentId);
            }

            if (!docIds.isEmpty()) {
                // Check for final (non-chunk) file with matching fileName
                // Title = :fileName already ensures exact match, so no need for NOT LIKE filter
                List<ContentVersion> finalFiles = [
                    SELECT Id
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docIds
                      AND Title = :fileName
                      AND IsLatest = true
                    LIMIT 1
                ];

                if (!finalFiles.isEmpty()) {
                    result.put('status', 'complete');
                    return result;
                }

                // Check for chunk files still present (assembly in progress)
                String statusChunkPattern = '__chunk__' + uploadKey + '__%';
                List<ContentVersion> chunks = [
                    SELECT Id
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docIds
                      AND Title LIKE :statusChunkPattern
                    LIMIT 1
                ];

                if (!chunks.isEmpty()) {
                    result.put('status', 'processing');
                    return result;
                }
            }

            // Check Error_Log__c for recent errors related to this case
            List<Error_Log__c> recentErrors = [
                SELECT Error_Message__c
                FROM Error_Log__c
                WHERE Form_Id__c = :caseId
                  AND Timestamp__c >= :DateTime.now().addMinutes(-5)
                ORDER BY Timestamp__c DESC
                LIMIT 1
            ];

            if (!recentErrors.isEmpty()) {
                result.put('status', 'error');
                result.put('error', 'File processing failed. Please try uploading again.');
                return result;
            }

            // No chunks, no final file, no error log:
            // This can happen if the Queueable has been picked up by the platform
            // and deleted chunks but hasn't yet created the final file.
            // Return 'processing' to let the client continue polling rather than
            // reporting a false failure.
            result.put('status', 'processing');

        } catch (Exception e) {
            ErrorLogger.logException(e, caseId);
            result.put('status', 'error');
            result.put('error', 'Error checking upload status.');
        }

        return result;
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
