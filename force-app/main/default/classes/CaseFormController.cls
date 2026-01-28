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

                    Boolean captchaValid = verifyCaptcha(captchaToken, settings.Secret_Key__c);
                    if (!captchaValid) {
                        result.put('success', false);
                        result.put('error', 'CAPTCHA verification failed. Please try again.');
                        return result;
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
     * Verify reCAPTCHA token with Google's API
     * @param token The reCAPTCHA response token from the client
     * @param secretKey The secret key from reCAPTCHA settings
     * @return true if verification successful, false otherwise
     */
    private static Boolean verifyCaptcha(String token, String secretKey) {
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
                return responseMap.get('success') == true;
            } else {
                ErrorLogger.log('reCAPTCHA verification HTTP error: ' + res.getStatusCode(), res.getBody());
                return false;
            }
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            return false;
        }
    }
}
