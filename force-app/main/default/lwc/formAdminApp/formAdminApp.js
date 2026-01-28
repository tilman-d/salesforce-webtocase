import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getForms from '@salesforce/apex/FormAdminController.getForms';
import deleteForm from '@salesforce/apex/FormAdminController.deleteForm';
import toggleFormActive from '@salesforce/apex/FormAdminController.toggleFormActive';

const COLUMNS = [
    {
        label: 'Form Name',
        fieldName: 'formName',
        type: 'button',
        typeAttributes: {
            label: { fieldName: 'formName' },
            name: 'editByName',
            variant: 'base'
        },
        cellAttributes: {
            class: 'slds-text-link'
        }
    },
    { label: 'Title', fieldName: 'title', type: 'text', sortable: true },
    { label: 'Fields', fieldName: 'fieldCount', type: 'number', sortable: true, initialWidth: 80 },
    {
        label: 'Active',
        fieldName: 'active',
        type: 'boolean',
        sortable: true,
        initialWidth: 80,
        cellAttributes: { alignment: 'center' }
    },
    {
        label: 'File Upload',
        fieldName: 'enableFileUpload',
        type: 'boolean',
        initialWidth: 100,
        cellAttributes: { alignment: 'center' }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Toggle Active', name: 'toggle' },
                { label: 'View Live', name: 'view' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class FormAdminApp extends LightningElement {
    @track forms = [];
    @track isLoading = true;
    @track currentView = 'list';
    @track selectedFormId = null;
    @track showDeleteModal = false;
    @track formToDelete = null;

    columns = COLUMNS;
    wiredFormsResult;

    @wire(getForms)
    wiredForms(result) {
        this.wiredFormsResult = result;
        if (result.data) {
            this.forms = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', this.getErrorMessage(result.error), 'error');
            this.isLoading = false;
        }
    }

    connectedCallback() {
        window.addEventListener('hashchange', this.handleHashChange);
        this.handleHashChange();
    }

    disconnectedCallback() {
        window.removeEventListener('hashchange', this.handleHashChange);
    }

    handleHashChange = () => {
        const hash = window.location.hash;
        if (hash.startsWith('#edit/')) {
            this.currentView = 'edit';
            this.selectedFormId = hash.replace('#edit/', '');
        } else if (hash === '#new') {
            this.currentView = 'edit';
            this.selectedFormId = null;
        } else {
            this.currentView = 'list';
            this.selectedFormId = null;
        }
    };

    get isListView() {
        return this.currentView === 'list';
    }

    get isEditView() {
        return this.currentView === 'edit';
    }

    get hasForms() {
        return this.forms && this.forms.length > 0;
    }

    get deleteModalMessage() {
        if (this.formToDelete) {
            return `Are you sure you want to delete "${this.formToDelete.title}"? This will also delete all ${this.formToDelete.fieldCount} field(s) associated with this form.`;
        }
        return '';
    }

    handleNewForm() {
        window.location.hash = '#new';
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        switch (action.name) {
            case 'edit':
            case 'editByName':
                window.location.hash = `#edit/${row.id}`;
                break;
            case 'toggle':
                this.handleToggleActive(row);
                break;
            case 'view':
                this.handleViewLive(row);
                break;
            case 'delete':
                this.formToDelete = row;
                this.showDeleteModal = true;
                break;
            default:
                break;
        }
    }

    handleToggleActive(row) {
        this.isLoading = true;
        toggleFormActive({ formId: row.id, active: !row.active })
            .then(() => {
                const status = !row.active ? 'activated' : 'deactivated';
                this.showToast('Success', `Form ${status}`, 'success');
                return refreshApex(this.wiredFormsResult);
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleViewLive(row) {
        // Open the public form in a new tab with preview=true to bypass active check
        const baseUrl = window.location.origin;
        const formUrl = `${baseUrl}/apex/CaseFormPage?form=${row.formName}&preview=true`;
        window.open(formUrl, '_blank');
    }

    handleCloseDeleteModal() {
        this.showDeleteModal = false;
        this.formToDelete = null;
    }

    handleConfirmDelete() {
        if (!this.formToDelete) return;

        this.isLoading = true;
        this.showDeleteModal = false;

        deleteForm({ formId: this.formToDelete.id })
            .then(() => {
                this.showToast('Success', 'Form deleted', 'success');
                this.formToDelete = null;
                return refreshApex(this.wiredFormsResult);
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleFormSaved(event) {
        const formId = event.detail.formId;
        this.showToast('Success', 'Form saved successfully', 'success');
        refreshApex(this.wiredFormsResult);
        window.location.hash = `#edit/${formId}`;
    }

    handleFormCancelled() {
        window.location.hash = '';
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
