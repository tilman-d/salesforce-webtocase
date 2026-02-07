import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFormWithFields from '@salesforce/apex/FormAdminController.getFormWithFields';
import getPicklistValues from '@salesforce/apex/FormAdminController.getPicklistValues';
import isFormNameAvailable from '@salesforce/apex/FormAdminController.isFormNameAvailable';
import saveForm from '@salesforce/apex/FormAdminController.saveForm';
import saveFields from '@salesforce/apex/FormAdminController.saveFields';
import getActiveSites from '@salesforce/apex/FormAdminController.getActiveSites';
import getDefaultSiteInfo from '@salesforce/apex/FormAdminController.getDefaultSiteInfo';

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
        maxFileSizeMB: 25, // Fixed: 25MB for images (auto-compressed), 4MB for documents (enforced in frontend)
        successMessage: '',
        enableCaptcha: false,
        siteId: null,
        allowedDomains: '',
        publicUrl: null
    };

    @track fields = [];
    @track isLoading = true;
    @track isSaving = false;
    @track expandedFieldIndex = null;
    @track formNameError = '';
    @track hasUnsavedChanges = false;
    @track sites = [];
    @track defaultSiteId = null;
    @track defaultBaseUrl = null;

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

    @wire(getActiveSites)
    wiredSites({ data, error }) {
        if (data) {
            this.sites = data;
        } else if (error) {
            console.error('Error loading sites:', error);
        }
    }

    @wire(getDefaultSiteInfo)
    wiredDefaultSiteInfo({ data, error }) {
        if (data) {
            this.defaultSiteId = data.siteId || null;
            this.defaultBaseUrl = data.baseUrl || null;
        } else if (error) {
            console.error('Error loading default site info:', error);
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
                        maxFileSizeMB: 25, // Fixed: 25MB for images, 4MB for documents (enforced in frontend)
                        successMessage: result.successMessage || '',
                        enableCaptcha: result.enableCaptcha || false,
                        siteId: result.siteId || null,
                        allowedDomains: result.allowedDomains || '',
                        publicUrl: result.publicUrl || null
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
                maxFileSizeMB: 25, // Fixed: 25MB for images, 4MB for documents (enforced in frontend)
                successMessage: '',
                enableCaptcha: false,
                siteId: null,
                allowedDomains: '',
                publicUrl: null
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

    get siteOptions() {
        const options = [];
        if (this.sites && this.sites.length > 0) {
            this.sites.forEach(site => {
                const isDefault = this.defaultSiteId && site.id === this.defaultSiteId;
                options.push({
                    label: isDefault ? site.masterLabel + ' (Default)' : site.masterLabel,
                    value: site.id
                });
            });
        }
        return options;
    }

    get effectiveSiteId() {
        // If form has explicit siteId, use it
        // Otherwise fall back to default
        return this.form.siteId || this.defaultSiteId || '';
    }

    get computedPublicUrl() {
        // If we have a saved publicUrl from the server, use it
        if (this.form.publicUrl) {
            return this.form.publicUrl;
        }
        // Otherwise compute it client-side for new/unsaved forms
        const baseUrl = this.resolvedBaseUrl;
        const formName = this.form.formName;
        if (baseUrl && formName) {
            const encodedFormName = encodeURIComponent(formName);
            let url = baseUrl;
            if (!url.endsWith('/')) {
                url += '/';
            }
            return url + 'apex/CaseFormPage?form=' + encodedFormName;
        }
        return null;
    }

    get resolvedBaseUrl() {
        // If form has a Site override, find its base URL
        if (this.form.siteId && this.sites) {
            const site = this.sites.find(s => s.id === this.form.siteId);
            if (site && site.baseUrl) {
                return site.baseUrl;
            }
        }
        // Otherwise use default
        return this.defaultBaseUrl;
    }

    get hasDefaultSite() {
        return !!this.defaultBaseUrl;
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

    handleCaptchaChange(event) {
        this.form.enableCaptcha = event.target.checked;
        this.hasUnsavedChanges = true;
    }

    handleSiteChange(event) {
        this.form.siteId = event.detail.value || null;
        // Clear the saved publicUrl so the computed one is used
        this.form.publicUrl = null;
        this.hasUnsavedChanges = true;
    }

    handleCopyUrl() {
        const url = this.computedPublicUrl;
        if (url) {
            navigator.clipboard.writeText(url).then(() => {
                this.showToast('Success', 'URL copied to clipboard', 'success');
            }).catch(() => {
                this.showToast('Error', 'Could not copy URL to clipboard', 'error');
            });
        }
    }

    handleAllowedDomainsChange(event) {
        this.form.allowedDomains = event.target.value;
        this.hasUnsavedChanges = true;
    }

    get hasAllowedDomains() {
        return this.form.allowedDomains && this.form.allowedDomains.trim().length > 0;
    }

    get embedApiBase() {
        const baseUrl = this.resolvedBaseUrl;
        if (!baseUrl) return '';
        // Remove trailing slash and add services/apexrest path
        let url = baseUrl;
        if (url.endsWith('/')) {
            url = url.slice(0, -1);
        }
        return url + '/services/apexrest';
    }

    get embedWidgetUrl() {
        const baseUrl = this.resolvedBaseUrl;
        if (!baseUrl) return '';
        let url = baseUrl;
        if (!url.endsWith('/')) {
            url += '/';
        }
        return url + 'resource/caseFormWidget';
    }

    get embedScriptSnippet() {
        const widgetUrl = this.embedWidgetUrl;
        const apiBase = this.embedApiBase;
        if (!widgetUrl || !apiBase) {
            return '<!-- Configure a Site in Settings to generate embed code -->';
        }
        const formName = this.form.formName || 'your-form-name';
        return `<div id="support-form"></div>
<script src="${widgetUrl}"></script>
<script>
  WebToCaseForm.render({
    formName: '${formName}',
    containerId: 'support-form',
    apiBase: '${apiBase}',
    onSuccess: function(caseNumber) {
      console.log('Case created:', caseNumber);
    },
    onError: function(error) {
      console.error('Error:', error);
    }
  });
</script>`;
    }

    get embedStyleSnippet() {
        return `<style>
  #support-form {
    --wtc-primary-color: #0176d3;
    --wtc-font-family: system-ui, -apple-system, sans-serif;
    --wtc-border-radius: 4px;
    --wtc-input-border: 1px solid #c9c9c9;
    --wtc-input-background: #ffffff;
    --wtc-text-color: #181818;
    --wtc-error-color: #c23934;
    --wtc-success-color: #2e844a;
  }
</style>`;
    }

    get embedIframeSnippet() {
        const publicUrl = this.computedPublicUrl;
        if (!publicUrl) {
            return '<!-- Configure a Site in Settings to generate embed code -->';
        }
        return `<iframe
  src="${publicUrl}&embed=1"
  style="width:100%; border:none; min-height:500px;"
  id="wtc-frame">
</iframe>
<script>
  window.addEventListener('message', function(e) {
    if (e.data && e.data.type === 'wtc:resize') {
      document.getElementById('wtc-frame').style.height = e.data.height + 'px';
    }
  });
</script>`;
    }

    handleCopyScriptCode() {
        this.copyToClipboard(this.embedScriptSnippet, 'Embed code copied to clipboard');
    }

    handleCopyStyleCode() {
        this.copyToClipboard(this.embedStyleSnippet, 'Style code copied to clipboard');
    }

    handleCopyIframeCode() {
        this.copyToClipboard(this.embedIframeSnippet, 'iframe code copied to clipboard');
    }

    copyToClipboard(text, successMessage) {
        navigator.clipboard.writeText(text).then(() => {
            this.showToast('Success', successMessage, 'success');
        }).catch(() => {
            this.showToast('Error', 'Could not copy to clipboard', 'error');
        });
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
                successMessage: this.form.successMessage,
                enableCaptcha: this.form.enableCaptcha,
                siteId: this.form.siteId,
                allowedDomains: this.form.allowedDomains
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
        const url = this.computedPublicUrl;
        if (url) {
            window.open(url + '&preview=true', '_blank');
        } else {
            this.showToast('Warning', 'No Site configured. Run the Setup Wizard to configure a default Site.', 'warning');
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
