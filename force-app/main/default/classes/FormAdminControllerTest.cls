/**
 * Test class for FormAdminController
 * Target: 90%+ code coverage
 */
@isTest
private class FormAdminControllerTest {

    @TestSetup
    static void setupTestData() {
        // Assign permission set for FLS in 2GP packaging context
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Web_to_Case_Admin' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id);

        // Create test forms
        Form__c form1 = new Form__c(
            Form_Name__c = 'test-form-one',
            Title__c = 'Test Form One',
            Description__c = 'Description for test form one',
            Active__c = true,
            Enable_File_Upload__c = true,
            Max_File_Size_MB__c = 5,
            Success_Message__c = 'Thank you for submitting'
        );

        Form__c form2 = new Form__c(
            Form_Name__c = 'test-form-two',
            Title__c = 'Test Form Two',
            Active__c = false
        );

        insert new List<Form__c>{ form1, form2 };

        // Create test fields for form1
        List<Form_Field__c> fields = new List<Form_Field__c>{
            new Form_Field__c(
                Form__c = form1.Id,
                Field_Label__c = 'Name',
                Field_Type__c = 'Text',
                Case_Field__c = 'SuppliedName',
                Required__c = true,
                Sort_Order__c = 1
            ),
            new Form_Field__c(
                Form__c = form1.Id,
                Field_Label__c = 'Email',
                Field_Type__c = 'Email',
                Case_Field__c = 'SuppliedEmail',
                Required__c = true,
                Sort_Order__c = 2
            ),
            new Form_Field__c(
                Form__c = form1.Id,
                Field_Label__c = 'Message',
                Field_Type__c = 'Textarea',
                Case_Field__c = 'Description',
                Required__c = false,
                Sort_Order__c = 3
            )
        };
        insert fields;
    }

    // Helper method to create form data map
    private static Map<String, Object> createFormData(String id, String formName, String title, String description,
            Boolean active, Boolean enableFileUpload, Decimal maxFileSizeMB, String successMessage) {
        Map<String, Object> formData = new Map<String, Object>();
        formData.put('id', id);
        formData.put('formName', formName);
        formData.put('title', title);
        formData.put('description', description);
        formData.put('active', active);
        formData.put('enableFileUpload', enableFileUpload);
        formData.put('maxFileSizeMB', maxFileSizeMB);
        formData.put('successMessage', successMessage);
        return formData;
    }

    // Helper method to create field data map
    private static Map<String, Object> createFieldData(String id, String fieldLabel, String fieldType,
            String caseField, Boolean required, Decimal sortOrder) {
        Map<String, Object> fieldData = new Map<String, Object>();
        fieldData.put('id', id);
        fieldData.put('fieldLabel', fieldLabel);
        fieldData.put('fieldType', fieldType);
        fieldData.put('caseField', caseField);
        fieldData.put('required', required);
        fieldData.put('sortOrder', sortOrder);
        return fieldData;
    }

    @isTest
    static void testGetForms() {
        Test.startTest();
        List<FormAdminController.FormWrapper> forms = FormAdminController.getForms();
        Test.stopTest();

        System.assertEquals(2, forms.size(), 'Should return 2 forms');

        // Find the form with fields
        FormAdminController.FormWrapper formWithFields;
        FormAdminController.FormWrapper formWithoutFields;
        for (FormAdminController.FormWrapper fw : forms) {
            if (fw.formName == 'test-form-one') {
                formWithFields = fw;
            } else {
                formWithoutFields = fw;
            }
        }

        System.assertNotEquals(null, formWithFields, 'Should find test-form-one');
        System.assertEquals(3, formWithFields.fieldCount, 'Form one should have 3 fields');
        System.assertEquals(0, formWithoutFields.fieldCount, 'Form two should have 0 fields');
        System.assertEquals(true, formWithFields.active, 'Form one should be active');
        System.assertEquals(false, formWithoutFields.active, 'Form two should be inactive');
    }

    @isTest
    static void testGetFormWithFields() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-one' LIMIT 1];

        Test.startTest();
        FormAdminController.FormWrapper wrapper = FormAdminController.getFormWithFields(form.Id);
        Test.stopTest();

        System.assertEquals('test-form-one', wrapper.formName, 'Form name should match');
        System.assertEquals('Test Form One', wrapper.title, 'Title should match');
        System.assertEquals(3, wrapper.fields.size(), 'Should have 3 fields');
        System.assertEquals(3, wrapper.fieldCount, 'Field count should be 3');

        // Verify field order
        System.assertEquals('Name', wrapper.fields[0].fieldLabel, 'First field should be Name');
        System.assertEquals('Email', wrapper.fields[1].fieldLabel, 'Second field should be Email');
        System.assertEquals('Message', wrapper.fields[2].fieldLabel, 'Third field should be Message');
    }

    @isTest
    static void testGetFormWithFieldsBlankId() {
        Test.startTest();
        try {
            FormAdminController.getFormWithFields('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetFormWithFieldsNotFound() {
        Test.startTest();
        try {
            // Use a fake ID
            FormAdminController.getFormWithFields('a00000000000000AAA');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form not found'), 'Should throw not found error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormCreate() {
        Map<String, Object> formData = createFormData(
            null, 'new-test-form', 'New Test Form', 'A new form',
            true, true, 15, 'Thanks!'
        );

        Test.startTest();
        String formId = FormAdminController.saveForm(formData);
        Test.stopTest();

        System.assertNotEquals(null, formId, 'Should return form ID');

        Form__c createdForm = [SELECT Id, Form_Name__c, Title__c, Active__c, Max_File_Size_MB__c
                               FROM Form__c WHERE Id = :formId];
        System.assertEquals('new-test-form', createdForm.Form_Name__c, 'Form name should match');
        System.assertEquals('New Test Form', createdForm.Title__c, 'Title should match');
        System.assertEquals(true, createdForm.Active__c, 'Should be active');
        System.assertEquals(15, createdForm.Max_File_Size_MB__c, 'Max file size should match');
    }

    @isTest
    static void testSaveFormUpdate() {
        Form__c existingForm = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-one' LIMIT 1];

        Map<String, Object> formData = createFormData(
            existingForm.Id, 'test-form-one', 'Updated Title', null,
            false, false, 10, null
        );

        Test.startTest();
        String formId = FormAdminController.saveForm(formData);
        Test.stopTest();

        System.assertEquals(existingForm.Id, formId, 'Should return same form ID');

        Form__c updatedForm = [SELECT Title__c, Active__c FROM Form__c WHERE Id = :formId];
        System.assertEquals('Updated Title', updatedForm.Title__c, 'Title should be updated');
        System.assertEquals(false, updatedForm.Active__c, 'Should be inactive');
    }

    @isTest
    static void testSaveFormNullData() {
        Test.startTest();
        try {
            FormAdminController.saveForm(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form data is required'), 'Should throw required data error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormEmptyData() {
        Test.startTest();
        try {
            FormAdminController.saveForm(new Map<String, Object>());
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form data is required'), 'Should throw required data error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormMissingFormName() {
        Map<String, Object> formData = createFormData(
            null, null, 'Test', null, false, false, 10, null
        );

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form Name is required'), 'Should throw required form name error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormMissingTitle() {
        Map<String, Object> formData = createFormData(
            null, 'test', null, null, false, false, 10, null
        );

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Title is required'), 'Should throw required title error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormInvalidFormName() {
        Map<String, Object> formData = createFormData(
            null, 'Invalid Name!', 'Test', null, false, false, 10, null
        );

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('lowercase letters, numbers, and hyphens'), 'Should throw invalid format error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormDuplicateName() {
        Map<String, Object> formData = createFormData(
            null, 'test-form-one', 'Test', null, false, false, 10, null
        );

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already in use'), 'Should throw duplicate name error');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteForm() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-two' LIMIT 1];

        Test.startTest();
        FormAdminController.deleteForm(form.Id);
        Test.stopTest();

        List<Form__c> remaining = [SELECT Id FROM Form__c WHERE Id = :form.Id];
        System.assertEquals(0, remaining.size(), 'Form should be deleted');
    }

    @isTest
    static void testDeleteFormWithFields() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-one' LIMIT 1];
        Integer fieldCountBefore = [SELECT COUNT() FROM Form_Field__c WHERE Form__c = :form.Id];
        System.assertEquals(3, fieldCountBefore, 'Should have 3 fields before delete');

        Test.startTest();
        FormAdminController.deleteForm(form.Id);
        Test.stopTest();

        List<Form__c> remainingForms = [SELECT Id FROM Form__c WHERE Id = :form.Id];
        System.assertEquals(0, remainingForms.size(), 'Form should be deleted');

        // Fields should cascade delete
        Integer fieldCountAfter = [SELECT COUNT() FROM Form_Field__c WHERE Form__c = :form.Id];
        System.assertEquals(0, fieldCountAfter, 'Fields should be cascade deleted');
    }

    @isTest
    static void testDeleteFormBlankId() {
        Test.startTest();
        try {
            FormAdminController.deleteForm('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    @isTest
    static void testToggleFormActive() {
        Form__c form = [SELECT Id, Active__c FROM Form__c WHERE Form_Name__c = 'test-form-one' LIMIT 1];
        System.assertEquals(true, form.Active__c, 'Form should be active initially');

        Test.startTest();
        FormAdminController.toggleFormActive(form.Id, false);
        Test.stopTest();

        form = [SELECT Active__c FROM Form__c WHERE Id = :form.Id];
        System.assertEquals(false, form.Active__c, 'Form should be inactive');
    }

    @isTest
    static void testToggleFormActiveBlankId() {
        Test.startTest();
        try {
            FormAdminController.toggleFormActive('', true);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFieldsCreate() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-two' LIMIT 1];

        List<Object> fields = new List<Object>();
        fields.add(createFieldData(null, 'Subject', 'Text', 'Subject', true, 1));

        Test.startTest();
        FormAdminController.saveFields(form.Id, fields);
        Test.stopTest();

        List<Form_Field__c> savedFields = [SELECT Field_Label__c FROM Form_Field__c WHERE Form__c = :form.Id];
        System.assertEquals(1, savedFields.size(), 'Should have 1 field');
        System.assertEquals('Subject', savedFields[0].Field_Label__c, 'Field label should match');
    }

    @isTest
    static void testSaveFieldsUpdate() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-one' LIMIT 1];
        Form_Field__c existingField = [SELECT Id FROM Form_Field__c WHERE Form__c = :form.Id AND Field_Label__c = 'Name' LIMIT 1];

        List<Object> fields = new List<Object>();
        fields.add(createFieldData(existingField.Id, 'Full Name', 'Text', 'SuppliedName', false, 1));

        Test.startTest();
        FormAdminController.saveFields(form.Id, fields);
        Test.stopTest();

        // Should have only 1 field (others deleted)
        List<Form_Field__c> savedFields = [SELECT Field_Label__c, Required__c FROM Form_Field__c WHERE Form__c = :form.Id];
        System.assertEquals(1, savedFields.size(), 'Should have 1 field after save');
        System.assertEquals('Full Name', savedFields[0].Field_Label__c, 'Field label should be updated');
        System.assertEquals(false, savedFields[0].Required__c, 'Required should be updated');
    }

    @isTest
    static void testSaveFieldsBlankFormId() {
        Test.startTest();
        try {
            FormAdminController.saveFields('', new List<Object>());
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Form ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFieldsNullList() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-one' LIMIT 1];

        Test.startTest();
        FormAdminController.saveFields(form.Id, null);
        Test.stopTest();

        // All fields should be deleted
        Integer fieldCount = [SELECT COUNT() FROM Form_Field__c WHERE Form__c = :form.Id];
        System.assertEquals(0, fieldCount, 'All fields should be deleted when null list passed');
    }

    @isTest
    static void testSaveFieldsMissingLabel() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-two' LIMIT 1];

        List<Object> fields = new List<Object>();
        fields.add(createFieldData(null, null, 'Text', 'Subject', false, 1));

        Test.startTest();
        try {
            FormAdminController.saveFields(form.Id, fields);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Field Label is required'), 'Should throw required label error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFieldsMissingType() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-two' LIMIT 1];

        List<Object> fields = new List<Object>();
        fields.add(createFieldData(null, 'Test', null, 'Subject', false, 1));

        Test.startTest();
        try {
            FormAdminController.saveFields(form.Id, fields);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Field Type is required'), 'Should throw required type error');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFieldsMissingCaseField() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-two' LIMIT 1];

        List<Object> fields = new List<Object>();
        fields.add(createFieldData(null, 'Test', 'Text', null, false, 1));

        Test.startTest();
        try {
            FormAdminController.saveFields(form.Id, fields);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Case Field is required'), 'Should throw required case field error');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteField() {
        Form_Field__c field = [SELECT Id FROM Form_Field__c WHERE Field_Label__c = 'Name' LIMIT 1];

        Test.startTest();
        FormAdminController.deleteField(field.Id);
        Test.stopTest();

        List<Form_Field__c> remaining = [SELECT Id FROM Form_Field__c WHERE Id = :field.Id];
        System.assertEquals(0, remaining.size(), 'Field should be deleted');
    }

    @isTest
    static void testDeleteFieldBlankId() {
        Test.startTest();
        try {
            FormAdminController.deleteField('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Field ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    @isTest
    static void testIsFormNameAvailable() {
        Test.startTest();
        Boolean available = FormAdminController.isFormNameAvailable('brand-new-name', null);
        Boolean notAvailable = FormAdminController.isFormNameAvailable('test-form-one', null);
        Test.stopTest();

        System.assertEquals(true, available, 'New name should be available');
        System.assertEquals(false, notAvailable, 'Existing name should not be available');
    }

    @isTest
    static void testIsFormNameAvailableWithExclude() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-one' LIMIT 1];

        Test.startTest();
        Boolean available = FormAdminController.isFormNameAvailable('test-form-one', form.Id);
        Test.stopTest();

        System.assertEquals(true, available, 'Same name should be available when excluding own ID');
    }

    @isTest
    static void testIsFormNameAvailableBlank() {
        Test.startTest();
        Boolean available = FormAdminController.isFormNameAvailable('', null);
        Test.stopTest();

        System.assertEquals(false, available, 'Blank name should not be available');
    }

    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        FormAdminController.PicklistValues values = FormAdminController.getPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, values, 'Should return picklist values');
        System.assert(values.fieldTypes.size() > 0, 'Should have field types');
        System.assert(values.caseFields.size() > 0, 'Should have case fields');

        // Verify expected values exist
        Boolean hasTextType = false;
        for (FormAdminController.PicklistOption opt : values.fieldTypes) {
            if (opt.value == 'Text') {
                hasTextType = true;
                break;
            }
        }
        System.assert(hasTextType, 'Should have Text field type');

        Boolean hasSubject = false;
        for (FormAdminController.PicklistOption opt : values.caseFields) {
            if (opt.value == 'Subject') {
                hasSubject = true;
                break;
            }
        }
        System.assert(hasSubject, 'Should have Subject case field');
    }

    @isTest
    static void testFormWrapperDefaultConstructor() {
        FormAdminController.FormWrapper wrapper = new FormAdminController.FormWrapper();

        System.assertEquals(false, wrapper.active, 'Active should default to false');
        System.assertEquals(false, wrapper.enableFileUpload, 'Enable file upload should default to false');
        System.assertEquals(10, wrapper.maxFileSizeMB, 'Max file size should default to 10');
        System.assertEquals(0, wrapper.fieldCount, 'Field count should default to 0');
        System.assertNotEquals(null, wrapper.fields, 'Fields list should be initialized');
    }

    @isTest
    static void testFieldWrapperDefaultConstructor() {
        FormAdminController.FieldWrapper wrapper = new FormAdminController.FieldWrapper();

        System.assertEquals(false, wrapper.required, 'Required should default to false');
        System.assertEquals(0, wrapper.sortOrder, 'Sort order should default to 0');
    }

    // ==================== Site-related Tests ====================

    @isTest
    static void testGetActiveSites() {
        Test.startTest();
        List<FormAdminController.SiteInfo> sites = FormAdminController.getActiveSites();
        Test.stopTest();

        // Sites may or may not exist in the test org, but method should not throw
        System.assertNotEquals(null, sites, 'Sites list should not be null');
    }

    @isTest
    static void testGetDefaultSiteInfo() {
        Test.startTest();
        Map<String, String> result = FormAdminController.getDefaultSiteInfo();
        Test.stopTest();

        // No default site configured in test, should return empty map or nulls
        System.assertNotEquals(null, result, 'Result map should not be null');
    }

    @isTest
    static void testGetDefaultSiteInfoWithSettings() {
        // Insert settings with default site info
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = '0DM000000000001',
            Default_Site_Base_Url__c = 'https://test.my.site.com/support'
        );
        insert settings;

        Test.startTest();
        Map<String, String> result = FormAdminController.getDefaultSiteInfo();
        Test.stopTest();

        System.assertEquals('0DM000000000001', result.get('siteId'), 'Site ID should match');
        System.assertEquals('https://test.my.site.com/support', result.get('baseUrl'), 'Base URL should match');
    }

    @isTest
    static void testBuildFormUrl() {
        Test.startTest();

        // Test with valid inputs
        String url = FormAdminController.buildFormUrl('https://test.my.site.com/support', 'contact-us');
        System.assertEquals('https://test.my.site.com/support/apex/CaseFormPage?form=contact-us', url,
            'URL should be correctly formatted');

        // Test with trailing slash
        String url2 = FormAdminController.buildFormUrl('https://test.my.site.com/support/', 'contact-us');
        System.assertEquals('https://test.my.site.com/support/apex/CaseFormPage?form=contact-us', url2,
            'URL should handle trailing slash');

        // Test URL encoding with special characters
        String url3 = FormAdminController.buildFormUrl('https://test.my.site.com', 'my form');
        System.assertEquals('https://test.my.site.com/apex/CaseFormPage?form=my+form', url3,
            'URL should encode spaces');

        // Test with blank base URL
        String url4 = FormAdminController.buildFormUrl('', 'contact-us');
        System.assertEquals(null, url4, 'Should return null for blank base URL');

        // Test with blank form name
        String url5 = FormAdminController.buildFormUrl('https://test.my.site.com', '');
        System.assertEquals(null, url5, 'Should return null for blank form name');

        // Test with null inputs
        String url6 = FormAdminController.buildFormUrl(null, null);
        System.assertEquals(null, url6, 'Should return null for null inputs');

        Test.stopTest();
    }

    @isTest
    static void testSiteInfoWrapper() {
        FormAdminController.SiteInfo info = new FormAdminController.SiteInfo();
        info.id = 'testId';
        info.name = 'TestSite';
        info.masterLabel = 'Test Site Label';
        info.baseUrl = 'https://test.my.site.com';

        System.assertEquals('testId', info.id, 'id should match');
        System.assertEquals('TestSite', info.name, 'name should match');
        System.assertEquals('Test Site Label', info.masterLabel, 'masterLabel should match');
        System.assertEquals('https://test.my.site.com', info.baseUrl, 'baseUrl should match');
    }

    @isTest
    static void testFormWrapperWithSiteId() {
        // Create a form with Site ID
        Form__c form = new Form__c(
            Form_Name__c = 'test-site-form',
            Title__c = 'Test Site Form',
            Active__c = true,
            Site_Id__c = '0DM000000000001'
        );
        insert form;

        Test.startTest();
        FormAdminController.FormWrapper wrapper = FormAdminController.getFormWithFields(form.Id);
        Test.stopTest();

        System.assertEquals('0DM000000000001', wrapper.siteId, 'Site ID should match');
    }

    @isTest
    static void testSaveFormWithSiteId() {
        Map<String, Object> formData = new Map<String, Object>();
        formData.put('id', null);
        formData.put('formName', 'site-override-form');
        formData.put('title', 'Site Override Form');
        formData.put('description', null);
        formData.put('active', true);
        formData.put('enableFileUpload', false);
        formData.put('maxFileSizeMB', 10);
        formData.put('successMessage', null);
        formData.put('enableCaptcha', false);
        formData.put('siteId', '0DM000000000001');

        Test.startTest();
        String formId = FormAdminController.saveForm(formData);
        Test.stopTest();

        Form__c savedForm = [SELECT Site_Id__c FROM Form__c WHERE Id = :formId];
        System.assertEquals('0DM000000000001', savedForm.Site_Id__c, 'Site ID should be saved');
    }

    @isTest
    static void testSaveFormClearSiteId() {
        // First create a form with Site ID
        Form__c form = new Form__c(
            Form_Name__c = 'clear-site-form',
            Title__c = 'Clear Site Form',
            Site_Id__c = '0DM000000000001'
        );
        insert form;

        // Now update it with empty siteId to clear it
        Map<String, Object> formData = new Map<String, Object>();
        formData.put('id', form.Id);
        formData.put('formName', 'clear-site-form');
        formData.put('title', 'Clear Site Form');
        formData.put('description', null);
        formData.put('active', false);
        formData.put('enableFileUpload', false);
        formData.put('maxFileSizeMB', 10);
        formData.put('successMessage', null);
        formData.put('enableCaptcha', false);
        formData.put('siteId', '');  // Empty string should clear the Site ID

        Test.startTest();
        FormAdminController.saveForm(formData);
        Test.stopTest();

        Form__c updatedForm = [SELECT Site_Id__c FROM Form__c WHERE Id = :form.Id];
        System.assertEquals(null, updatedForm.Site_Id__c, 'Site ID should be cleared');
    }

    // ==================== Default Case Values Tests ====================

    @isTest
    static void testGetCaseFieldsForDefaults() {
        Test.startTest();
        List<FormAdminController.CaseFieldInfo> fields = FormAdminController.getCaseFieldsForDefaults();
        Test.stopTest();

        System.assertEquals(5, fields.size(), 'Should return 5 allowed fields');

        // Verify all fields have required properties
        Set<String> returnedNames = new Set<String>();
        for (FormAdminController.CaseFieldInfo fi : fields) {
            returnedNames.add(fi.apiName);
            System.assertNotEquals(null, fi.label, 'Label should not be null for ' + fi.apiName);
            System.assertNotEquals(null, fi.fieldType, 'Field type should not be null for ' + fi.apiName);
            // Picklist fields should have values
            if (fi.fieldType == 'PICKLIST') {
                System.assert(fi.picklistValues.size() > 0, 'Picklist field ' + fi.apiName + ' should have values');
            }
        }

        // Verify expected fields are present
        System.assert(returnedNames.contains('Priority'), 'Should contain Priority');
        System.assert(returnedNames.contains('Status'), 'Should contain Status');
        System.assert(returnedNames.contains('Origin'), 'Should contain Origin');
        System.assert(returnedNames.contains('Type'), 'Should contain Type');
        System.assert(returnedNames.contains('Reason'), 'Should contain Reason');
    }

    @isTest
    static void testSaveFormWithDefaultCaseValues() {
        Map<String, Object> formData = createFormData(
            null, 'defaults-test', 'Defaults Test Form', null,
            true, false, 10, null
        );
        formData.put('defaultCaseValues', '{"Priority":"High","Type":"Problem"}');

        Test.startTest();
        String formId = FormAdminController.saveForm(formData);
        Test.stopTest();

        // Verify round-trip
        Form__c savedForm = [SELECT Default_Case_Values__c FROM Form__c WHERE Id = :formId];
        System.assertNotEquals(null, savedForm.Default_Case_Values__c, 'Default case values should be saved');
        System.assert(savedForm.Default_Case_Values__c.contains('Priority'), 'Should contain Priority');
        System.assert(savedForm.Default_Case_Values__c.contains('High'), 'Should contain High');

        // Verify it loads back via getFormWithFields
        FormAdminController.FormWrapper wrapper = FormAdminController.getFormWithFields(formId);
        System.assertEquals('{"Priority":"High","Type":"Problem"}', wrapper.defaultCaseValues, 'Wrapper should have default values');
    }

    @isTest
    static void testSaveFormRejectsInvalidDefaultFieldName() {
        Map<String, Object> formData = createFormData(
            null, 'bad-field-test', 'Bad Field Test', null,
            false, false, 10, null
        );
        formData.put('defaultCaseValues', '{"AccountId":"001000000000001"}');

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Invalid default Case field'), 'Should reject disallowed field');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormRejectsInvalidJson() {
        Map<String, Object> formData = createFormData(
            null, 'bad-json-test', 'Bad JSON Test', null,
            false, false, 10, null
        );
        formData.put('defaultCaseValues', '{not valid json}');

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('invalid JSON'), 'Should reject malformed JSON');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormRejectsBlankDefaultValue() {
        Map<String, Object> formData = createFormData(
            null, 'blank-val-test', 'Blank Val Test', null,
            false, false, 10, null
        );
        formData.put('defaultCaseValues', '{"Priority":""}');

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('non-blank string'), 'Should reject blank value');
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveFormClearsDefaultValues() {
        // Create a form with defaults first
        Form__c form = new Form__c(
            Form_Name__c = 'clear-defaults-test',
            Title__c = 'Clear Defaults Test',
            Default_Case_Values__c = '{"Priority":"High"}'
        );
        insert form;

        // Update with null defaults to clear
        Map<String, Object> formData = createFormData(
            form.Id, 'clear-defaults-test', 'Clear Defaults Test', null,
            false, false, 10, null
        );
        formData.put('defaultCaseValues', null);

        Test.startTest();
        FormAdminController.saveForm(formData);
        Test.stopTest();

        Form__c updated = [SELECT Default_Case_Values__c FROM Form__c WHERE Id = :form.Id];
        System.assertEquals(null, updated.Default_Case_Values__c, 'Default values should be cleared');
    }

    @isTest
    static void testCaseFieldInfoWrapper() {
        List<FormAdminController.PicklistOption> opts = new List<FormAdminController.PicklistOption>();
        opts.add(new FormAdminController.PicklistOption('High', 'High'));

        FormAdminController.CaseFieldInfo info = new FormAdminController.CaseFieldInfo(
            'Priority', 'Priority', 'PICKLIST', opts
        );

        System.assertEquals('Priority', info.apiName, 'apiName should match');
        System.assertEquals('Priority', info.label, 'label should match');
        System.assertEquals('PICKLIST', info.fieldType, 'fieldType should match');
        System.assertEquals(1, info.picklistValues.size(), 'Should have 1 picklist value');
    }

    // ==================== CRUD Denial Tests ====================

    @isTest
    static void testSaveFormNoCrudAccess() {
        FormAdminController.testDenyCrud = true;

        Map<String, Object> formData = createFormData(
            null, 'crud-test', 'CRUD Test', null,
            false, false, 10, null
        );

        Test.startTest();
        try {
            FormAdminController.saveForm(formData);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permission'),
                'Error should mention permission: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteFormNoCrudAccess() {
        Form__c form = [SELECT Id FROM Form__c WHERE Form_Name__c = 'test-form-two' LIMIT 1];
        FormAdminController.testDenyCrud = true;

        Test.startTest();
        try {
            FormAdminController.deleteForm(form.Id);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permission'),
                'Error should mention permission: ' + e.getMessage());
        }
        Test.stopTest();

        // Verify form was NOT deleted
        List<Form__c> remaining = [SELECT Id FROM Form__c WHERE Id = :form.Id];
        System.assertEquals(1, remaining.size(), 'Form should NOT be deleted when CRUD denied');
    }

    @isTest
    static void testGetFormsNoCrudAccess() {
        FormAdminController.testDenyCrud = true;

        Test.startTest();
        try {
            FormAdminController.getForms();
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permission'),
                'Error should mention permission: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testGetFormsWithPublicUrl() {
        // Insert default site settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = '0DM000000000001',
            Default_Site_Base_Url__c = 'https://test.my.site.com/support'
        );
        insert settings;

        Test.startTest();
        List<FormAdminController.FormWrapper> forms = FormAdminController.getForms();
        Test.stopTest();

        // Should have forms from TestSetup
        System.assert(forms.size() > 0, 'Should have forms');

        // All forms should have public URLs computed
        for (FormAdminController.FormWrapper fw : forms) {
            System.assertNotEquals(null, fw.publicUrl, 'Public URL should be computed for form: ' + fw.formName);
            System.assert(fw.publicUrl.contains('apex/CaseFormPage'), 'Public URL should contain page path');
            System.assert(fw.publicUrl.contains('form=' + fw.formName), 'Public URL should contain form name');
        }
    }
}
