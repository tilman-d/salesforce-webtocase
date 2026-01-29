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
        @AuraEnabled public Integer fieldCount;
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
            this.fieldCount = fieldCount;
            this.fields = new List<FieldWrapper>();
            this.createdDate = form.CreatedDate;
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

        // Query all forms
        for (Form__c form : [
            SELECT Id, Form_Name__c, Title__c, Description__c, Active__c,
                   Enable_File_Upload__c, Max_File_Size_MB__c, Success_Message__c, Enable_Captcha__c,
                   CreatedDate
            FROM Form__c
            ORDER BY CreatedDate DESC
        ]) {
            Integer count = fieldCounts.containsKey(form.Id) ? fieldCounts.get(form.Id) : 0;
            wrappers.add(new FormWrapper(form, count));
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
                   CreatedDate
            FROM Form__c
            WHERE Id = :formId
            LIMIT 1
        ];

        if (forms.isEmpty()) {
            throw createException('Form not found');
        }

        Form__c form = forms[0];
        FormWrapper wrapper = new FormWrapper(form, 0);

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
}
