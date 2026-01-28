# Web-to-Case with Attachments

A Salesforce app that lets you create public web forms that submit Cases with file attachments. Built for the AppExchange.

## Why This Exists

Salesforce's native Web-to-Case doesn't support file attachments. This app solves that problem with:
- Configurable forms stored as custom objects
- Public Visualforce page for form rendering
- File attachments via ContentVersion/ContentDocumentLink
- Error logging for debugging

---

## Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 0** | MVP - Core form submission | ✅ Complete |
| **Phase 1** | Admin UI (LWC form builder) | ⬜ Not started |
| **Phase 2** | reCAPTCHA integration | ⬜ Not started |
| **Phase 3** | Embeddable widget, multi-file upload | ⬜ Not started |

---

## What's Built (Phase 0)

### Custom Objects
- **Form__c** - Form configuration (name, title, description, file upload settings)
- **Form_Field__c** - Field definitions (label, type, Case field mapping, required, sort order)
- **Error_Log__c** - Error logging for debugging

### Apex Classes
- **CaseFormController** - Main controller for form rendering and submission (88% coverage)
- **ErrorLogger** - Utility for logging errors (95% coverage)
- **CaseFormControllerTest** - Test class
- **ErrorLoggerTest** - Test class

### Visualforce
- **CaseFormPage** - Public form page that renders dynamically based on Form__c configuration

### Static Resources
- **caseFormStyles.css** - Clean, responsive form styling
- **caseFormScript.js** - Client-side validation and form submission

### Permission Set
- **Web_to_Case_Admin** - Admin access to form management

---

## Deployment

### Prerequisites
- Salesforce CLI (`sf`) installed
- Access to a Salesforce org (Developer Edition or Sandbox)

### 1. Deploy Code
```bash
sf org login web --alias myorg
sf project deploy start --target-org myorg
sf apex run test --target-org myorg --test-level RunLocalTests
```

### 2. Create Test Data
Run this anonymous Apex to create a sample form:
```apex
Form__c form = new Form__c(
    Form_Name__c = 'support',
    Title__c = 'Contact Support',
    Description__c = 'We\'ll get back to you within 24 hours.',
    Success_Message__c = 'Thank you! Your case has been submitted.',
    Active__c = true,
    Enable_File_Upload__c = true,
    Max_File_Size_MB__c = 10
);
insert form;

List<Form_Field__c> fields = new List<Form_Field__c>{
    new Form_Field__c(Form__c = form.Id, Field_Label__c = 'Your Name', Field_Type__c = 'Text', Case_Field__c = 'SuppliedName', Required__c = true, Sort_Order__c = 1),
    new Form_Field__c(Form__c = form.Id, Field_Label__c = 'Email Address', Field_Type__c = 'Email', Case_Field__c = 'SuppliedEmail', Required__c = true, Sort_Order__c = 2),
    new Form_Field__c(Form__c = form.Id, Field_Label__c = 'Subject', Field_Type__c = 'Text', Case_Field__c = 'Subject', Required__c = true, Sort_Order__c = 3),
    new Form_Field__c(Form__c = form.Id, Field_Label__c = 'Message', Field_Type__c = 'Textarea', Case_Field__c = 'Description', Required__c = true, Sort_Order__c = 4)
};
insert fields;
```

### 3. Create Salesforce Site
1. Setup → Sites → Register your domain
2. Create new site:
   - Site Label: `Support`
   - Site Name: `support` (or `s` for shorter URL)
   - Active Site Home Page: `CaseFormPage`
3. Activate the site

### 4. Configure Guest User Profile
On the Site detail page → Public Access Settings:

**Object Permissions:**
| Object | Read | Create |
|--------|------|--------|
| Form__c | ✓ | |
| Form_Field__c | ✓ | |
| Case | | ✓ |
| ContentVersion | | ✓ |
| ContentDocumentLink | | ✓ |
| Error_Log__c | | ✓ |

**Field Permissions (Form__c):** Read access to Description__c, Enable_File_Upload__c, Max_File_Size_MB__c, Success_Message__c

**Field Permissions (Form_Field__c):** Read access to Required__c

**Apex Class Access:** CaseFormController, ErrorLogger

**VF Page Access:** CaseFormPage

### 5. Test
Access: `https://[your-domain].my.salesforce-sites.com/support/CaseFormPage?name=support`

---

## Roadmap

### Phase 1: Admin UI
- LWC form builder (create/edit forms without Setup)
- Field drag-drop reordering
- Form preview
- Copy/duplicate forms

### Phase 2: reCAPTCHA
- Google reCAPTCHA v2 integration
- Per-form toggle
- Protected custom settings for API keys

### Phase 3: Advanced Features
- Embeddable JavaScript widget
- Multi-file upload
- Custom field types (picklist, date)
- Form analytics/submission tracking

---

## Project Structure

```
force-app/main/default/
├── objects/
│   ├── Form__c/              # Form configuration
│   ├── Form_Field__c/        # Field definitions
│   └── Error_Log__c/         # Error logging
├── classes/
│   ├── CaseFormController.cls
│   ├── CaseFormControllerTest.cls
│   ├── ErrorLogger.cls
│   └── ErrorLoggerTest.cls
├── pages/
│   └── CaseFormPage.page
├── staticresources/
│   ├── caseFormStyles.css
│   └── caseFormScript.js
└── permissionsets/
    └── Web_to_Case_Admin.permissionset-meta.xml
```

---

## Troubleshooting

### Form shows "Form Not Available"
- Verify Form__c record exists with matching `Form_Name__c`
- Verify `Active__c = true`
- Check Guest User has Read access to Form__c

### File upload not showing
- Verify `Enable_File_Upload__c = true` on the Form__c record
- Check Guest User has Read access to `Enable_File_Upload__c` field

### Submission fails
- Check Error_Log__c for error details
- Verify Guest User has Create access to Case, ContentVersion, ContentDocumentLink
- Enable debug logs for the Guest User

---

## Changelog

### v0.1.0 (2026-01-28) - Phase 0 MVP
- Initial release
- Form__c, Form_Field__c, Error_Log__c custom objects
- CaseFormController with file attachment support
- CaseFormPage Visualforce page
- Basic styling and client-side validation
- Error logging utility
- 21 tests passing, 88%+ code coverage
