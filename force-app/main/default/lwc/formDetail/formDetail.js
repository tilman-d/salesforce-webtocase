import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFormWithFields from '@salesforce/apex/FormAdminController.getFormWithFields';
import getPicklistValues from '@salesforce/apex/FormAdminController.getPicklistValues';
import isFormNameAvailable from '@salesforce/apex/FormAdminController.isFormNameAvailable';
import saveForm from '@salesforce/apex/FormAdminController.saveForm';
import saveFields from '@salesforce/apex/FormAdminController.saveFields';

export default class FormDetail extends LightningElement {
    _formId;
    _isConnected = false;

    @api
    get formId() {
        return this._formId;
    }
    set formId(value) {
        const changed = this._formId !== value;
        this._formId = value;
        // Reload form when formId changes and component is connected
        if (changed && this._isConnected) {
            this.loadForm();
        }
    }

    @track form = {
        id: null,
        formName: '',
        title: '',
        description: '',
        active: false,
        enableFileUpload: false,
        maxFileSizeMB: 10,
        successMessage: ''
    };

    @track fields = [];
    @track isLoading = true;
    @track isSaving = false;
    @track expandedFieldIndex = null;
    @track formNameError = '';
    @track hasUnsavedChanges = false;

    fieldTypeOptions = [];
    caseFieldOptions = [];

    @wire(getPicklistValues)
    wiredPicklistValues({ data, error }) {
        if (data) {
            this.fieldTypeOptions = data.fieldTypes.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
            this.caseFieldOptions = data.caseFields.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load picklist values', 'error');
        }
    }

    connectedCallback() {
        this._isConnected = true;
        this.loadForm();
    }

    disconnectedCallback() {
        this._isConnected = false;
    }

    loadForm() {
        this.isLoading = true;

        if (this.formId) {
            getFormWithFields({ formId: this.formId })
                .then(result => {
                    this.form = {
                        id: result.id,
                        formName: result.formName || '',
                        title: result.title || '',
                        description: result.description || '',
                        active: result.active || false,
                        enableFileUpload: result.enableFileUpload || false,
                        maxFileSizeMB: result.maxFileSizeMB || 10,
                        successMessage: result.successMessage || ''
                    };
                    this.fields = (result.fields || []).map((f, index) => ({
                        ...f,
                        tempId: `field-${index}`,
                        expanded: false
                    }));
                    this.hasUnsavedChanges = false;
                })
                .catch(error => {
                    this.showToast('Error', this.getErrorMessage(error), 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            // New form
            this.form = {
                id: null,
                formName: '',
                title: '',
                description: '',
                active: false,
                enableFileUpload: false,
                maxFileSizeMB: 10,
                successMessage: ''
            };
            this.fields = [];
            this.isLoading = false;
            this.hasUnsavedChanges = false;
        }
    }

    get isNewForm() {
        return !this.formId;
    }

    get activeSections() {
        return ['settings', 'fields'];
    }

    get pageTitle() {
        return this.isNewForm ? 'New Form' : 'Edit Form';
    }

    get hasFields() {
        return this.fields && this.fields.length > 0;
    }

    get fieldsWithIndex() {
        return this.fields.map((field, index) => ({
            ...field,
            index,
            isFirst: index === 0,
            isLast: index === this.fields.length - 1,
            isExpanded: this.expandedFieldIndex === index,
            displayIndex: index + 1,
            chevronIcon: this.expandedFieldIndex === index ? 'utility:chevrondown' : 'utility:chevronright'
        }));
    }

    get canSave() {
        return this.form.formName && this.form.title && !this.formNameError;
    }

    // Form field handlers
    handleFormNameChange(event) {
        const value = event.target.value;
        // Auto-format: lowercase, replace spaces with hyphens, remove invalid chars
        this.form.formName = value.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
        this.hasUnsavedChanges = true;
        this.validateFormName();
    }

    handleTitleChange(event) {
        this.form.title = event.target.value;
        this.hasUnsavedChanges = true;
    }

    handleDescriptionChange(event) {
        this.form.description = event.target.value;
        this.hasUnsavedChanges = true;
    }

    handleActiveChange(event) {
        this.form.active = event.target.checked;
        this.hasUnsavedChanges = true;
    }

    handleFileUploadChange(event) {
        this.form.enableFileUpload = event.target.checked;
        this.hasUnsavedChanges = true;
    }

    handleMaxFileSizeChange(event) {
        this.form.maxFileSizeMB = event.target.value;
        this.hasUnsavedChanges = true;
    }

    handleSuccessMessageChange(event) {
        this.form.successMessage = event.target.value;
        this.hasUnsavedChanges = true;
    }

    validateFormName() {
        if (!this.form.formName) {
            this.formNameError = '';
            return;
        }

        if (!/^[a-z0-9-]+$/.test(this.form.formName)) {
            this.formNameError = 'Only lowercase letters, numbers, and hyphens allowed';
            return;
        }

        // Check uniqueness
        isFormNameAvailable({ formName: this.form.formName, excludeId: this.form.id })
            .then(available => {
                if (!available) {
                    this.formNameError = 'This form name is already in use';
                } else {
                    this.formNameError = '';
                }
            })
            .catch(() => {
                // Ignore validation errors
            });
    }

    // Field handlers
    handleAddField() {
        const newField = {
            id: null,
            tempId: `field-new-${Date.now()}`,
            fieldLabel: '',
            fieldType: 'Text',
            caseField: 'Subject',
            required: false,
            sortOrder: this.fields.length + 1,
            expanded: true
        };
        this.fields = [...this.fields, newField];
        this.expandedFieldIndex = this.fields.length - 1;
        this.hasUnsavedChanges = true;
    }

    handleToggleField(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        if (this.expandedFieldIndex === index) {
            this.expandedFieldIndex = null;
        } else {
            this.expandedFieldIndex = index;
        }
    }

    handleFieldLabelChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.fields[index].fieldLabel = event.target.value;
        this.fields = [...this.fields];
        this.hasUnsavedChanges = true;
    }

    handleFieldTypeChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.fields[index].fieldType = event.target.value;
        this.fields = [...this.fields];
        this.hasUnsavedChanges = true;
    }

    handleCaseFieldChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.fields[index].caseField = event.target.value;
        this.fields = [...this.fields];
        this.hasUnsavedChanges = true;
    }

    handleRequiredChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.fields[index].required = event.target.checked;
        this.fields = [...this.fields];
        this.hasUnsavedChanges = true;
    }

    handleMoveFieldUp(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        if (index > 0) {
            const newFields = [...this.fields];
            [newFields[index], newFields[index - 1]] = [newFields[index - 1], newFields[index]];
            this.updateSortOrders(newFields);
            this.fields = newFields;
            if (this.expandedFieldIndex === index) {
                this.expandedFieldIndex = index - 1;
            } else if (this.expandedFieldIndex === index - 1) {
                this.expandedFieldIndex = index;
            }
            this.hasUnsavedChanges = true;
        }
    }

    handleMoveFieldDown(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        if (index < this.fields.length - 1) {
            const newFields = [...this.fields];
            [newFields[index], newFields[index + 1]] = [newFields[index + 1], newFields[index]];
            this.updateSortOrders(newFields);
            this.fields = newFields;
            if (this.expandedFieldIndex === index) {
                this.expandedFieldIndex = index + 1;
            } else if (this.expandedFieldIndex === index + 1) {
                this.expandedFieldIndex = index;
            }
            this.hasUnsavedChanges = true;
        }
    }

    handleDeleteField(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const newFields = this.fields.filter((_, i) => i !== index);
        this.updateSortOrders(newFields);
        this.fields = newFields;
        if (this.expandedFieldIndex === index) {
            this.expandedFieldIndex = null;
        } else if (this.expandedFieldIndex > index) {
            this.expandedFieldIndex--;
        }
        this.hasUnsavedChanges = true;
    }

    updateSortOrders(fields) {
        fields.forEach((field, index) => {
            field.sortOrder = index + 1;
        });
    }

    // Save and Cancel
    async handleSave() {
        // Validate form
        if (!this.form.formName) {
            this.showToast('Error', 'Form Name is required', 'error');
            return;
        }
        if (!this.form.title) {
            this.showToast('Error', 'Title is required', 'error');
            return;
        }
        if (this.formNameError) {
            this.showToast('Error', this.formNameError, 'error');
            return;
        }

        // Validate fields
        for (const field of this.fields) {
            if (!field.fieldLabel) {
                this.showToast('Error', 'All fields must have a label', 'error');
                return;
            }
            if (!field.fieldType) {
                this.showToast('Error', 'All fields must have a type', 'error');
                return;
            }
            if (!field.caseField) {
                this.showToast('Error', 'All fields must have a Case Field mapping', 'error');
                return;
            }
        }

        this.isSaving = true;

        try {
            // Save form first
            const formData = {
                id: this.form.id,
                formName: this.form.formName,
                title: this.form.title,
                description: this.form.description,
                active: this.form.active,
                enableFileUpload: this.form.enableFileUpload,
                maxFileSizeMB: this.form.maxFileSizeMB,
                successMessage: this.form.successMessage
            };

            const formId = await saveForm({ formData: formData });
            this.form.id = formId;

            // Then save fields
            const fieldsData = this.fields.map(f => ({
                id: f.id,
                fieldLabel: f.fieldLabel,
                fieldType: f.fieldType,
                caseField: f.caseField,
                required: f.required,
                sortOrder: f.sortOrder
            }));

            await saveFields({ formId: formId, fields: fieldsData });

            this.hasUnsavedChanges = false;
            this.showToast('Success', 'Form saved successfully', 'success');

            // Dispatch event to parent
            this.dispatchEvent(new CustomEvent('formsaved', {
                detail: { formId: formId }
            }));

        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('formcancelled'));
    }

    handleViewLive() {
        if (this.form.formName) {
            const baseUrl = window.location.origin;
            const formUrl = `${baseUrl}/apex/CaseFormPage?form=${this.form.formName}&preview=true`;
            window.open(formUrl, '_blank');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'An unexpected error occurred';
    }
}
