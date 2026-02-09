/**
 * Controller for LWC Admin UI - Form Management
 * Provides CRUD operations for Form__c and Form_Field__c objects
 */
public with sharing class FormAdminController {

    /**
     * Wrapper class for Form__c with field count
     */
    public class FormWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String formName;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Boolean enableFileUpload;
        @AuraEnabled public Decimal maxFileSizeMB;
        @AuraEnabled public String successMessage;
        @AuraEnabled public Boolean enableCaptcha;
        @AuraEnabled public String siteId;
        @AuraEnabled public String allowedDomains;
        @AuraEnabled public String publicUrl;
        @AuraEnabled public Integer fieldCount;
        @AuraEnabled public String defaultCaseValues;
        @AuraEnabled public List<FieldWrapper> fields;
        @AuraEnabled public Datetime createdDate;

        public FormWrapper() {
            this.fields = new List<FieldWrapper>();
            this.active = false;
            this.enableFileUpload = false;
            this.maxFileSizeMB = 10;
            this.enableCaptcha = false;
            this.fieldCount = 0;
        }

        public FormWrapper(Form__c form, Integer fieldCount) {
            this.id = form.Id;
            this.formName = form.Form_Name__c;
            this.title = form.Title__c;
            this.description = form.Description__c;
            this.active = form.Active__c;
            this.enableFileUpload = form.Enable_File_Upload__c;
            this.maxFileSizeMB = form.Max_File_Size_MB__c;
            this.successMessage = form.Success_Message__c;
            this.enableCaptcha = form.Enable_Captcha__c;
            this.siteId = form.Site_Id__c;
            this.allowedDomains = form.Allowed_Domains__c;
            this.defaultCaseValues = form.Default_Case_Values__c;
            this.fieldCount = fieldCount;
            this.fields = new List<FieldWrapper>();
            this.createdDate = form.CreatedDate;
        }
    }

    /**
     * Wrapper class for Site info
     */
    public class SiteInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String masterLabel;
        @AuraEnabled public String baseUrl;

        public SiteInfo() {}

        public SiteInfo(Site s, String baseUrl) {
            this.id = s.Id;
            this.name = s.Name;
            this.masterLabel = s.MasterLabel;
            this.baseUrl = baseUrl;
        }
    }

    /**
     * Wrapper class for Form_Field__c
     */
    public class FieldWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldType;
        @AuraEnabled public String caseField;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Decimal sortOrder;

        public FieldWrapper() {
            this.required = false;
            this.sortOrder = 0;
        }

        public FieldWrapper(Form_Field__c field) {
            this.id = field.Id;
            this.fieldLabel = field.Field_Label__c;
            this.fieldType = field.Field_Type__c;
            this.caseField = field.Case_Field__c;
            this.required = field.Required__c;
            this.sortOrder = field.Sort_Order__c;
        }
    }

    /**
     * Wrapper class for picklist options
     */
    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * Wrapper class for all picklist values
     */
    public class PicklistValues {
        @AuraEnabled public List<PicklistOption> fieldTypes;
        @AuraEnabled public List<PicklistOption> caseFields;

        public PicklistValues() {
            this.fieldTypes = new List<PicklistOption>();
            this.caseFields = new List<PicklistOption>();
        }
    }

    /**
     * Helper method to create AuraHandledException with proper message
     */
    private static AuraHandledException createException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * Get all forms with field counts
     */
    @AuraEnabled(cacheable=true)
    public static List<FormWrapper> getForms() {
        List<FormWrapper> wrappers = new List<FormWrapper>();

        // Query forms with aggregate count of fields
        Map<Id, Integer> fieldCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Form__c, COUNT(Id) cnt
            FROM Form_Field__c
            GROUP BY Form__c
        ]) {
            fieldCounts.put((Id)ar.get('Form__c'), (Integer)ar.get('cnt'));
        }

        // Get default Site info once
        Map<String, String> defaultSiteInfo = getDefaultSiteInfo();
        String defaultBaseUrl = defaultSiteInfo.get('baseUrl');

        // Build a map of Site IDs to base URLs for forms with overrides
        Set<String> siteIds = new Set<String>();
        List<Form__c> forms = [
            SELECT Id, Form_Name__c, Title__c, Description__c, Active__c,
                   Enable_File_Upload__c, Max_File_Size_MB__c, Success_Message__c, Enable_Captcha__c,
                   Site_Id__c, Allowed_Domains__c, Default_Case_Values__c, CreatedDate
            FROM Form__c
            ORDER BY CreatedDate DESC
        ];

        for (Form__c form : forms) {
            if (String.isNotBlank(form.Site_Id__c)) {
                siteIds.add(form.Site_Id__c);
            }
        }

        // Get base URLs for all unique Site IDs
        Map<String, String> siteBaseUrls = new Map<String, String>();
        for (String siteId : siteIds) {
            String baseUrl = getSiteBaseUrl(siteId);
            if (String.isNotBlank(baseUrl)) {
                siteBaseUrls.put(siteId, baseUrl);
            }
        }

        // Build wrappers with public URLs
        for (Form__c form : forms) {
            Integer count = fieldCounts.containsKey(form.Id) ? fieldCounts.get(form.Id) : 0;
            FormWrapper wrapper = new FormWrapper(form, count);

            // Resolve base URL: form override or default
            String baseUrl = String.isNotBlank(form.Site_Id__c) && siteBaseUrls.containsKey(form.Site_Id__c)
                ? siteBaseUrls.get(form.Site_Id__c)
                : defaultBaseUrl;

            wrapper.publicUrl = buildFormUrl(baseUrl, form.Form_Name__c);
            wrappers.add(wrapper);
        }

        return wrappers;
    }

    /**
     * Get single form with all fields
     */
    @AuraEnabled(cacheable=true)
    public static FormWrapper getFormWithFields(String formId) {
        if (String.isBlank(formId)) {
            throw createException('Form ID is required');
        }

        List<Form__c> forms = [
            SELECT Id, Form_Name__c, Title__c, Description__c, Active__c,
                   Enable_File_Upload__c, Max_File_Size_MB__c, Success_Message__c, Enable_Captcha__c,
                   Site_Id__c, Allowed_Domains__c, Default_Case_Values__c, CreatedDate
            FROM Form__c
            WHERE Id = :formId
            LIMIT 1
        ];

        if (forms.isEmpty()) {
            throw createException('Form not found');
        }

        Form__c form = forms[0];
        FormWrapper wrapper = new FormWrapper(form, 0);

        // Compute public URL
        String baseUrl;
        if (String.isNotBlank(form.Site_Id__c)) {
            baseUrl = getSiteBaseUrl(form.Site_Id__c);
        }
        if (String.isBlank(baseUrl)) {
            Map<String, String> defaultSiteInfo = getDefaultSiteInfo();
            baseUrl = defaultSiteInfo.get('baseUrl');
        }
        wrapper.publicUrl = buildFormUrl(baseUrl, form.Form_Name__c);

        // Get fields
        List<Form_Field__c> fields = [
            SELECT Id, Field_Label__c, Field_Type__c, Case_Field__c, Required__c, Sort_Order__c
            FROM Form_Field__c
            WHERE Form__c = :formId
            ORDER BY Sort_Order__c ASC NULLS LAST
        ];

        wrapper.fieldCount = fields.size();
        for (Form_Field__c field : fields) {
            wrapper.fields.add(new FieldWrapper(field));
        }

        return wrapper;
    }

    /**
     * Create or update form
     */
    @AuraEnabled
    public static String saveForm(Map<String, Object> formData) {
        if (formData == null || formData.isEmpty()) {
            throw createException('Form data is required');
        }

        String formId = (String)formData.get('id');
        String formName = (String)formData.get('formName');
        String title = (String)formData.get('title');
        String description = (String)formData.get('description');
        Boolean active = (Boolean)formData.get('active');
        Boolean enableFileUpload = (Boolean)formData.get('enableFileUpload');
        Decimal maxFileSizeMB = formData.get('maxFileSizeMB') != null ? Decimal.valueOf(String.valueOf(formData.get('maxFileSizeMB'))) : 10;
        String successMessage = (String)formData.get('successMessage');
        Boolean enableCaptcha = (Boolean)formData.get('enableCaptcha');
        String siteId = (String)formData.get('siteId');
        String allowedDomains = (String)formData.get('allowedDomains');
        String defaultCaseValues = (String)formData.get('defaultCaseValues');

        // Validate required fields
        if (String.isBlank(formName)) {
            throw createException('Form Name is required');
        }
        if (String.isBlank(title)) {
            throw createException('Title is required');
        }

        // Validate form name format (URL-safe)
        if (!Pattern.matches('^[a-z0-9-]+$', formName)) {
            throw createException('Form Name must contain only lowercase letters, numbers, and hyphens');
        }

        // Check uniqueness
        if (!isFormNameAvailable(formName, formId)) {
            throw createException('Form Name is already in use');
        }

        Form__c form;
        if (String.isNotBlank(formId)) {
            // Update existing
            form = new Form__c(Id = formId);
        } else {
            // Create new
            form = new Form__c();
        }

        form.Form_Name__c = formName;
        form.Title__c = title;
        form.Description__c = description;
        form.Active__c = active == true;
        form.Enable_File_Upload__c = enableFileUpload == true;
        form.Max_File_Size_MB__c = maxFileSizeMB;
        form.Success_Message__c = successMessage;
        form.Enable_Captcha__c = enableCaptcha == true;
        form.Site_Id__c = String.isNotBlank(siteId) ? siteId : null;
        form.Allowed_Domains__c = allowedDomains;

        // Validate and assign default case values
        if (String.isNotBlank(defaultCaseValues)) {
            try {
                Object parsed = JSON.deserializeUntyped(defaultCaseValues);
                if (!(parsed instanceof Map<String, Object>)) {
                    throw createException('Default Case Values must be a JSON object');
                }
                Map<String, Object> defaults = (Map<String, Object>) parsed;
                for (String key : defaults.keySet()) {
                    if (!CaseDefaultFieldConfig.ALLOWED_FIELDS.contains(key)) {
                        throw createException('Invalid default Case field: ' + key + '. Allowed fields: ' + CaseDefaultFieldConfig.ALLOWED_FIELDS);
                    }
                    Object val = defaults.get(key);
                    if (val == null || !(val instanceof String) || String.isBlank((String) val)) {
                        throw createException('Default value for ' + key + ' must be a non-blank string');
                    }
                }
            } catch (JSONException je) {
                throw createException('Default Case Values contains invalid JSON: ' + je.getMessage());
            }
            form.Default_Case_Values__c = defaultCaseValues;
        } else {
            form.Default_Case_Values__c = null;
        }

        try {
            upsert form;
            return form.Id;
        } catch (DmlException e) {
            throw createException('Error saving form: ' + e.getMessage());
        }
    }

    /**
     * Delete form (fields cascade delete via master-detail)
     */
    @AuraEnabled
    public static void deleteForm(String formId) {
        if (String.isBlank(formId)) {
            throw createException('Form ID is required');
        }

        try {
            delete new Form__c(Id = formId);
        } catch (DmlException e) {
            throw createException('Error deleting form: ' + e.getMessage());
        }
    }

    /**
     * Toggle form active status
     */
    @AuraEnabled
    public static void toggleFormActive(String formId, Boolean active) {
        if (String.isBlank(formId)) {
            throw createException('Form ID is required');
        }

        try {
            update new Form__c(Id = formId, Active__c = active);
        } catch (DmlException e) {
            throw createException('Error updating form: ' + e.getMessage());
        }
    }

    /**
     * Batch save all fields for a form
     */
    @AuraEnabled
    public static void saveFields(String formId, List<Object> fields) {
        if (String.isBlank(formId)) {
            throw createException('Form ID is required');
        }

        if (fields == null) {
            fields = new List<Object>();
        }

        List<Form_Field__c> fieldsToUpsert = new List<Form_Field__c>();
        Set<Id> fieldIdsToKeep = new Set<Id>();

        for (Object fieldObj : fields) {
            // Convert using JSON to handle Map<ANY,ANY> from LWC
            Map<String, Object> fw = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(fieldObj));
            String fieldId = (String)fw.get('id');
            String fieldLabel = (String)fw.get('fieldLabel');
            String fieldType = (String)fw.get('fieldType');
            String caseField = (String)fw.get('caseField');
            Boolean required = (Boolean)fw.get('required');
            Decimal sortOrder = fw.get('sortOrder') != null ? Decimal.valueOf(String.valueOf(fw.get('sortOrder'))) : 0;

            // Validate required fields
            if (String.isBlank(fieldLabel)) {
                throw createException('Field Label is required for all fields');
            }
            if (String.isBlank(fieldType)) {
                throw createException('Field Type is required for all fields');
            }
            if (String.isBlank(caseField)) {
                throw createException('Case Field is required for all fields');
            }

            Form_Field__c field;
            if (String.isNotBlank(fieldId)) {
                field = new Form_Field__c(Id = fieldId);
                fieldIdsToKeep.add(fieldId);
            } else {
                field = new Form_Field__c(Form__c = formId);
            }

            field.Field_Label__c = fieldLabel;
            field.Field_Type__c = fieldType;
            field.Case_Field__c = caseField;
            field.Required__c = required == true;
            field.Sort_Order__c = sortOrder;

            fieldsToUpsert.add(field);
        }

        // Delete fields that were removed
        List<Form_Field__c> existingFields = [
            SELECT Id FROM Form_Field__c WHERE Form__c = :formId
        ];
        List<Form_Field__c> fieldsToDelete = new List<Form_Field__c>();
        for (Form_Field__c ef : existingFields) {
            if (!fieldIdsToKeep.contains(ef.Id)) {
                fieldsToDelete.add(ef);
            }
        }

        try {
            if (!fieldsToDelete.isEmpty()) {
                delete fieldsToDelete;
            }
            if (!fieldsToUpsert.isEmpty()) {
                upsert fieldsToUpsert;
            }
        } catch (DmlException e) {
            throw createException('Error saving fields: ' + e.getMessage());
        }
    }

    /**
     * Delete single field
     */
    @AuraEnabled
    public static void deleteField(String fieldId) {
        if (String.isBlank(fieldId)) {
            throw createException('Field ID is required');
        }

        try {
            delete new Form_Field__c(Id = fieldId);
        } catch (DmlException e) {
            throw createException('Error deleting field: ' + e.getMessage());
        }
    }

    /**
     * Check if form name is available (unique)
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isFormNameAvailable(String formName, String excludeId) {
        if (String.isBlank(formName)) {
            return false;
        }

        String query = 'SELECT Id FROM Form__c WHERE Form_Name__c = :formName';
        List<Form__c> existing;

        if (String.isNotBlank(excludeId)) {
            existing = Database.query(query + ' AND Id != :excludeId LIMIT 1');
        } else {
            existing = Database.query(query + ' LIMIT 1');
        }

        return existing.isEmpty();
    }

    /**
     * Get picklist values for Field Type and Case Field
     */
    @AuraEnabled(cacheable=true)
    public static PicklistValues getPicklistValues() {
        PicklistValues result = new PicklistValues();

        // Get Field Type picklist values
        Schema.DescribeFieldResult fieldTypeDesc = Form_Field__c.Field_Type__c.getDescribe();
        for (Schema.PicklistEntry pe : fieldTypeDesc.getPicklistValues()) {
            if (pe.isActive()) {
                result.fieldTypes.add(new PicklistOption(pe.getLabel(), pe.getValue()));
            }
        }

        // Get Case Field picklist values
        Schema.DescribeFieldResult caseFieldDesc = Form_Field__c.Case_Field__c.getDescribe();
        for (Schema.PicklistEntry pe : caseFieldDesc.getPicklistValues()) {
            if (pe.isActive()) {
                result.caseFields.add(new PicklistOption(pe.getLabel(), pe.getValue()));
            }
        }

        return result;
    }

    /**
     * Get active sites for dropdown
     */
    @AuraEnabled(cacheable=true)
    public static List<SiteInfo> getActiveSites() {
        List<SiteInfo> sites = new List<SiteInfo>();

        try {
            for (Site s : [
                SELECT Id, Name, MasterLabel
                FROM Site
                WHERE Status = 'Active'
                ORDER BY MasterLabel ASC
            ]) {
                String baseUrl = getSiteBaseUrl(s.Id);
                sites.add(new SiteInfo(s, baseUrl));
            }
        } catch (Exception e) {
            // If Sites feature is not enabled or query fails, return empty list
        }

        return sites;
    }

    /**
     * Get default site info from settings
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getDefaultSiteInfo() {
        Map<String, String> result = new Map<String, String>();

        try {
            reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
            if (settings != null && settings.Id != null) {
                result.put('siteId', settings.Default_Site_Id__c);
                result.put('baseUrl', settings.Default_Site_Base_Url__c);
            }
        } catch (Exception e) {
            // Return empty map on error
        }

        return result;
    }

    /**
     * Helper to get Site base URL (via SiteDetail)
     */
    private static String getSiteBaseUrl(String siteId) {
        try {
            List<SiteDetail> details = [
                SELECT SecureUrl
                FROM SiteDetail
                WHERE DurableId = :siteId
            ];
            if (!details.isEmpty() && String.isNotBlank(details[0].SecureUrl)) {
                return details[0].SecureUrl;
            }
        } catch (Exception e) {
            // Return null on error
        }
        return null;
    }

    /**
     * Wrapper class for Case field info used by default values UI
     */
    public class CaseFieldInfo {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String fieldType;
        @AuraEnabled public List<PicklistOption> picklistValues;

        public CaseFieldInfo(String apiName, String label, String fieldType, List<PicklistOption> picklistValues) {
            this.apiName = apiName;
            this.label = label;
            this.fieldType = fieldType;
            this.picklistValues = picklistValues;
        }
    }

    /**
     * Get Case field metadata for the allowed default fields.
     * Returns field labels, types, and active picklist values.
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseFieldInfo> getCaseFieldsForDefaults() {
        List<CaseFieldInfo> result = new List<CaseFieldInfo>();
        Map<String, Schema.SObjectField> caseFields = Schema.SObjectType.Case.fields.getMap();

        for (String fieldName : CaseDefaultFieldConfig.ALLOWED_FIELDS) {
            Schema.SObjectField field = caseFields.get(fieldName.toLowerCase());
            if (field == null) {
                continue;
            }
            Schema.DescribeFieldResult dfr = field.getDescribe();
            String fieldType = dfr.getType().name();
            List<PicklistOption> plValues = new List<PicklistOption>();

            if (dfr.getType() == Schema.DisplayType.PICKLIST) {
                for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                    if (pe.isActive()) {
                        plValues.add(new PicklistOption(pe.getLabel(), pe.getValue()));
                    }
                }
            }

            result.add(new CaseFieldInfo(fieldName, dfr.getLabel(), fieldType, plValues));
        }

        return result;
    }

    /**
     * Build public URL for a form (server-side, URL-encoded)
     */
    public static String buildFormUrl(String baseUrl, String formName) {
        if (String.isBlank(baseUrl) || String.isBlank(formName)) {
            return null;
        }
        String url = baseUrl;
        if (!url.endsWith('/')) {
            url += '/';
        }
        url += 'apex/CaseFormPage?form=' + EncodingUtil.urlEncode(formName, 'UTF-8');
        return url;
    }
}
