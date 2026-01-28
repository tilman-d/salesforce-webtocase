# Phase 1: Admin UI - Web-to-Case with Attachments

## Prerequisites

**Phase 0 must be complete and working before starting Phase 1.**

Verify Phase 0:
- [ ] CaseFormPage.page renders forms correctly
- [ ] Case creation works with file attachments
- [ ] Error logging works
- [ ] Tests pass

---

## Goal

Add Lightning Web Components (LWC) admin UI so users can create and manage forms without using Salesforce Setup.

---

## What We're Building

```
┌─────────────────────────────────────────────────────────────┐
│                    ADMIN INTERFACE                          │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Form Builder Tab (Lightning App Page)                │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ formBuilderHome                                 │  │  │
│  │  │ ├── List all forms (active/inactive)            │  │  │
│  │  │ ├── Create new form button                      │  │  │
│  │  │ ├── Edit / Delete / Copy actions                │  │  │
│  │  │ └── Quick status toggle                         │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                         │                              │  │
│  │                         ▼                              │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ formEditor (Modal or Slide Panel)               │  │  │
│  │  │ ├── Form settings (name, title, description)    │  │  │
│  │  │ ├── File upload settings                        │  │  │
│  │  │ └── Save / Cancel                               │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                         │                              │  │
│  │                         ▼                              │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ formFieldList                                   │  │  │
│  │  │ ├── List fields with drag-drop reorder          │  │  │
│  │  │ ├── Add field button                            │  │  │
│  │  │ └── Edit / Delete field actions                 │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                         │                              │  │
│  │                         ▼                              │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ formFieldEditor (Modal)                         │  │  │
│  │  │ ├── Field label, type, mapping                  │  │  │
│  │  │ ├── Required toggle                             │  │  │
│  │  │ └── Save / Cancel                               │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Components to Build

### 1. formBuilderHome (LWC)
Main component displayed on the Form Builder tab.

**Features:**
- Datatable showing all Form__c records
- Columns: Name, Title, Status (Active/Inactive), Created Date, Actions
- "New Form" button
- Row actions: Edit, Delete, Copy, Toggle Active
- Search/filter capability

**Apex Controller:** FormBuilderController.cls
```apex
public with sharing class FormBuilderController {

    @AuraEnabled(cacheable=true)
    public static List<Form__c> getAllForms() {
        return [
            SELECT Id, Name, Form_Name__c, Title__c, Active__c,
                   Enable_File_Upload__c, CreatedDate
            FROM Form__c
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void deleteForm(Id formId) {
        delete [SELECT Id FROM Form__c WHERE Id = :formId];
    }

    @AuraEnabled
    public static void toggleFormActive(Id formId, Boolean isActive) {
        update new Form__c(Id = formId, Active__c = isActive);
    }

    @AuraEnabled
    public static Form__c copyForm(Id formId) {
        Form__c original = [
            SELECT Form_Name__c, Title__c, Description__c, Success_Message__c,
                   Active__c, Enable_File_Upload__c, Max_File_Size_MB__c
            FROM Form__c WHERE Id = :formId
        ];

        Form__c copy = original.clone(false, true, false, false);
        copy.Form_Name__c = original.Form_Name__c + '-copy';
        copy.Title__c = original.Title__c + ' (Copy)';
        copy.Active__c = false;
        insert copy;

        // Copy fields
        List<Form_Field__c> originalFields = [
            SELECT Field_Label__c, Field_Type__c, Case_Field__c,
                   Required__c, Sort_Order__c
            FROM Form_Field__c WHERE Form__c = :formId
        ];

        List<Form_Field__c> newFields = new List<Form_Field__c>();
        for (Form_Field__c f : originalFields) {
            Form_Field__c newField = f.clone(false, true, false, false);
            newField.Form__c = copy.Id;
            newFields.add(newField);
        }
        insert newFields;

        return copy;
    }
}
```

### 2. formEditor (LWC)
Edit form settings. Opens in a modal.

**Features:**
- Input fields for all Form__c fields
- Validation (Form_Name__c must be unique, URL-safe)
- Auto-generate Form_Name__c from Title
- Preview URL display
- Save/Cancel buttons

**Fields to edit:**
- Form_Name__c (URL identifier)
- Title__c
- Description__c (rich text or textarea)
- Success_Message__c
- Active__c
- Enable_File_Upload__c
- Max_File_Size_MB__c

### 3. formFieldList (LWC)
Manage fields for a form.

**Features:**
- List of Form_Field__c records
- Drag-and-drop reordering (updates Sort_Order__c)
- "Add Field" button
- Row actions: Edit, Delete
- Visual indicator for required fields

**Apex Controller additions:**
```apex
@AuraEnabled
public static List<Form_Field__c> getFormFields(Id formId) {
    return [
        SELECT Id, Field_Label__c, Field_Type__c, Case_Field__c,
               Required__c, Sort_Order__c
        FROM Form_Field__c
        WHERE Form__c = :formId
        ORDER BY Sort_Order__c ASC
    ];
}

@AuraEnabled
public static void reorderFields(List<Id> fieldIds) {
    List<Form_Field__c> updates = new List<Form_Field__c>();
    for (Integer i = 0; i < fieldIds.size(); i++) {
        updates.add(new Form_Field__c(
            Id = fieldIds[i],
            Sort_Order__c = i + 1
        ));
    }
    update updates;
}

@AuraEnabled
public static void deleteField(Id fieldId) {
    delete [SELECT Id FROM Form_Field__c WHERE Id = :fieldId];
}
```

### 4. formFieldEditor (LWC)
Edit a single field. Opens in a modal.

**Features:**
- Field Label input
- Field Type picklist (Text, Email, Textarea)
- Case Field mapping picklist
- Required checkbox
- Help text input (optional - add to data model)
- Save/Cancel buttons

**Apex Controller additions:**
```apex
@AuraEnabled
public static Form_Field__c saveField(Form_Field__c field) {
    upsert field;
    return field;
}
```

---

## Files to Create

```
force-app/main/default/
├── classes/
│   ├── FormBuilderController.cls
│   ├── FormBuilderController.cls-meta.xml
│   ├── FormBuilderControllerTest.cls
│   └── FormBuilderControllerTest.cls-meta.xml
├── lwc/
│   ├── formBuilderHome/
│   │   ├── formBuilderHome.html
│   │   ├── formBuilderHome.js
│   │   ├── formBuilderHome.js-meta.xml
│   │   └── formBuilderHome.css
│   ├── formEditor/
│   │   ├── formEditor.html
│   │   ├── formEditor.js
│   │   ├── formEditor.js-meta.xml
│   │   └── formEditor.css
│   ├── formFieldList/
│   │   ├── formFieldList.html
│   │   ├── formFieldList.js
│   │   ├── formFieldList.js-meta.xml
│   │   └── formFieldList.css
│   └── formFieldEditor/
│       ├── formFieldEditor.html
│       ├── formFieldEditor.js
│       ├── formFieldEditor.js-meta.xml
│       └── formFieldEditor.css
├── tabs/
│   └── Form_Builder.tab-meta.xml
└── flexipages/
    └── Form_Builder.flexipage-meta.xml
```

---

## LWC Implementation Details

### formBuilderHome.html
```html
<template>
    <lightning-card title="Web-to-Case Forms" icon-name="standard:form">
        <div slot="actions">
            <lightning-button
                label="New Form"
                variant="brand"
                onclick={handleNewForm}>
            </lightning-button>
        </div>

        <div class="slds-p-horizontal_medium">
            <lightning-datatable
                key-field="Id"
                data={forms}
                columns={columns}
                onrowaction={handleRowAction}
                hide-checkbox-column>
            </lightning-datatable>
        </div>
    </lightning-card>

    <!-- Form Editor Modal -->
    <template if:true={showFormEditor}>
        <c-form-editor
            form-id={selectedFormId}
            onclose={handleEditorClose}
            onsave={handleEditorSave}>
        </c-form-editor>
    </template>

    <!-- Field List Modal -->
    <template if:true={showFieldList}>
        <c-form-field-list
            form-id={selectedFormId}
            onclose={handleFieldListClose}>
        </c-form-field-list>
    </template>
</template>
```

### formBuilderHome.js
```javascript
import { LightningElement, wire, track } from 'lwc';
import getAllForms from '@salesforce/apex/FormBuilderController.getAllForms';
import deleteForm from '@salesforce/apex/FormBuilderController.deleteForm';
import toggleFormActive from '@salesforce/apex/FormBuilderController.toggleFormActive';
import copyForm from '@salesforce/apex/FormBuilderController.copyForm';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Form Name', fieldName: 'Form_Name__c', type: 'text' },
    { label: 'Title', fieldName: 'Title__c', type: 'text' },
    {
        label: 'Status',
        fieldName: 'Active__c',
        type: 'boolean',
        cellAttributes: {
            iconName: { fieldName: 'statusIcon' },
            iconPosition: 'left'
        }
    },
    { label: 'Created', fieldName: 'CreatedDate', type: 'date' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit Settings', name: 'edit' },
                { label: 'Manage Fields', name: 'fields' },
                { label: 'Copy', name: 'copy' },
                { label: 'Toggle Active', name: 'toggle' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class FormBuilderHome extends LightningElement {
    @track forms = [];
    @track showFormEditor = false;
    @track showFieldList = false;
    @track selectedFormId = null;

    columns = COLUMNS;
    wiredFormsResult;

    @wire(getAllForms)
    wiredForms(result) {
        this.wiredFormsResult = result;
        if (result.data) {
            this.forms = result.data.map(form => ({
                ...form,
                statusIcon: form.Active__c ? 'utility:success' : 'utility:clear'
            }));
        }
    }

    handleNewForm() {
        this.selectedFormId = null;
        this.showFormEditor = true;
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        switch (action) {
            case 'edit':
                this.selectedFormId = row.Id;
                this.showFormEditor = true;
                break;
            case 'fields':
                this.selectedFormId = row.Id;
                this.showFieldList = true;
                break;
            case 'copy':
                this.handleCopy(row.Id);
                break;
            case 'toggle':
                this.handleToggle(row.Id, !row.Active__c);
                break;
            case 'delete':
                this.handleDelete(row.Id);
                break;
        }
    }

    async handleCopy(formId) {
        try {
            await copyForm({ formId });
            this.showToast('Success', 'Form copied', 'success');
            refreshApex(this.wiredFormsResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    async handleToggle(formId, isActive) {
        try {
            await toggleFormActive({ formId, isActive });
            refreshApex(this.wiredFormsResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    async handleDelete(formId) {
        if (!confirm('Delete this form and all its fields?')) return;
        try {
            await deleteForm({ formId });
            this.showToast('Success', 'Form deleted', 'success');
            refreshApex(this.wiredFormsResult);
        } catch (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    handleEditorClose() {
        this.showFormEditor = false;
        this.selectedFormId = null;
    }

    handleEditorSave() {
        this.showFormEditor = false;
        this.selectedFormId = null;
        refreshApex(this.wiredFormsResult);
    }

    handleFieldListClose() {
        this.showFieldList = false;
        this.selectedFormId = null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
```

---

## Data Model Additions (Optional)

Consider adding these fields for Phase 1:

### Form__c additions
- `Case_Owner_Id__c` (Text 18) - Default Case owner/queue
- `Case_Record_Type_Id__c` (Text 18) - Record type for Cases

### Form_Field__c additions
- `Help_Text__c` (Text 500) - Help text shown below field
- `Placeholder__c` (Text 255) - Placeholder text in input

---

## Testing Phase 1

### Unit Tests
- FormBuilderControllerTest.cls covering all methods
- Test CRUD operations on Form__c and Form_Field__c
- Test permission enforcement

### Manual Testing
1. Open Form Builder tab
2. Create new form with all settings
3. Add 4-5 fields of different types
4. Reorder fields via drag-drop
5. Edit a field
6. Delete a field
7. Toggle form active/inactive
8. Copy a form
9. Delete a form
10. Verify public form still works with new data

---

## Success Criteria

Phase 1 is complete when:
1. Admin can create forms without Setup access
2. Admin can add/edit/delete/reorder fields
3. Admin can copy and manage form status
4. All changes reflect correctly in public form
5. Tests pass with 75%+ coverage

---

## Next Phase

After Phase 1 is validated, proceed to **Future Phases** for reCAPTCHA, debug dashboard, and embed support.
