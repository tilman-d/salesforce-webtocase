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
                          'Max_File_Size_MB__c FROM Form__c WHERE Form_Name__c = :formName';
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
     * Get the captcha site key (placeholder for future implementation)
     */
    public String getCaptchaSiteKey() {
        return '';
    }

    /**
     * Submit the form and create a Case with optional file attachment
     * @param formId ID of the form being submitted
     * @param fieldValues Map of Case field API names to values
     * @param fileName Name of the attached file (empty if no file)
     * @param fileContent Base64 encoded file content (empty if no file)
     * @return Map containing success status, case number or error message
     */
    @RemoteAction
    global static Map<String, Object> submitForm(String formId, Map<String, String> fieldValues,
                                                  String fileName, String fileContent) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Validate form exists and is active
            List<Form__c> forms = [
                SELECT Id, Form_Name__c, Enable_File_Upload__c, Max_File_Size_MB__c
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
}
