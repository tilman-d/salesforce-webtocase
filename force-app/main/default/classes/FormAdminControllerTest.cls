/**
 * Test class for FormAdminController
 * Target: 90%+ code coverage
 */
@isTest
private class FormAdminControllerTest {

    @TestSetup
    static void setupTestData() {
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
}
