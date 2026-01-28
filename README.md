# Web-to-Case with Attachments

A Salesforce app that lets you create public web forms that submit Cases with file attachments. Built for the AppExchange.

## Why This Exists

Salesforce's native Web-to-Case doesn't support file attachments. This app solves that problem with:
- Configurable forms stored as custom objects
- Public Visualforce page for form rendering
- File attachments via ContentVersion/ContentDocumentLink
- LWC Admin UI for managing forms without using Setup
- Error logging for debugging

---

## Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 0** | MVP - Core form submission | ✅ Complete |
| **Phase 1** | Admin UI (LWC form builder) | ✅ Complete |
| **Phase 2** | Post-Install Setup Wizard | 🔜 **Next up** |
| **Phase 3** | reCAPTCHA integration | ⬜ Not started |
| **Phase 4** | Embeddable widget, multi-file upload | ⬜ Not started |

---

## What's Built (Phase 0)

### Custom Objects
- **Form__c** - Form configuration (name, title, description, file upload settings)
- **Form_Field__c** - Field definitions (label, type, Case field mapping, required, sort order)
- **Error_Log__c** - Error logging for debugging

### Apex Classes
- **CaseFormController** - Main controller for form rendering and submission
- **ErrorLogger** - Utility for logging errors

### Visualforce
- **CaseFormPage** - Public form page that renders dynamically based on Form__c configuration

### Static Resources
- **caseFormStyles.css** - Clean, responsive form styling
- **caseFormScript.js** - Client-side validation and form submission

---

## What's Built (Phase 1)

### LWC Admin UI
Access via the **Form Manager** tab in Salesforce.

**Features:**
- List all forms with field counts
- Create new forms
- Edit existing forms (click form name to edit)
- Delete forms with confirmation modal
- Toggle form active/inactive status
- Add, edit, delete, and reorder fields
- Preview forms with "View Live" button
- URL hash routing for bookmarkable links (`#new`, `#edit/{formId}`)
- Form name validation (unique, URL-safe)
- Toast notifications for success/error feedback

### Apex Classes
- **FormAdminController** - CRUD operations for Form__c and Form_Field__c with wrapper classes
- **FormAdminControllerTest** - 33 unit tests, 94%+ code coverage

### LWC Components
- **formAdminApp** - Main container with list view, routing, and delete modal
- **formDetail** - Form settings editor with inline field management

### Metadata
- **Form_Manager.flexipage-meta.xml** - Lightning App Page
- **Form_Manager.tab-meta.xml** - Navigation tab

### Permission Set Updates
- Added FormAdminController class access
- Added Form_Manager tab visibility

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

Or use the **Form Manager** tab to create forms via the UI (Phase 1).

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

## Using the Form Manager (Phase 1)

1. Navigate to the **Form Manager** tab in Salesforce
2. Click **New Form** to create a form
3. Fill in form settings:
   - **Form Name**: URL-safe identifier (lowercase, hyphens only)
   - **Title**: Display title shown on the form
   - **Description**: Instructions shown at the top
   - **Success Message**: Shown after submission
   - **Active**: Toggle to enable/disable the form
   - **Enable File Upload**: Allow file attachments
4. Add fields in the **Form Fields** section
5. Click **Save**
6. Use **View Live** to preview the form

---

## Roadmap

### Phase 2: Post-Install Setup Wizard (NEXT)

**Problem:** Current setup requires 10+ manual steps across multiple Setup screens. Guest User permissions are complex and error-prone. Most admins would give up or misconfigure.

**Solution:** An LWC-based 5-step setup wizard.

**Technical Research Complete:**
| Configuration | Can Automate | Method |
|--------------|--------------|--------|
| Detect existing Sites | ✅ Yes | SOQL on Site object |
| Create new Site | ❌ No | Manual (Metadata API too complex) |
| Object Permissions | ✅ Yes | ObjectPermissions via Profile's PermissionSet |
| Field Permissions | ✅ Yes | FieldPermissions via Profile's PermissionSet |
| Apex Class Access | ❌ No | Manual (cannot set on Guest Profile programmatically) |
| VF Page Access | ❌ No | Manual (cannot set on Guest Profile programmatically) |
| Create sample form | ✅ Yes | Standard DML |

**Key insight:** Guest User Profiles have a linked PermissionSet record. We can modify ObjectPermissions and FieldPermissions on that PermissionSet to configure the Guest User.

**Wizard Flow (5 Steps):**
1. **Welcome & Preconditions** - Check My Domain, admin permissions, Sites enabled
2. **Select Site** - Choose from existing Sites or guide manual creation
3. **Auto-Configure** - Set object/field permissions with security warning
4. **Manual Steps** - Instructions for Apex/VF access with validation
5. **Complete** - Show public URL, test link, create sample form

**Files to create:**
- `SetupWizardController.cls` - Site detection, permission config, validation
- `SetupWizardControllerTest.cls` - Unit tests
- `setupWizard/` LWC - Multi-step wizard UI
- `Setup_Wizard.flexipage-meta.xml` - Lightning page
- `Setup_Wizard.tab-meta.xml` - Navigation tab

**Detailed plan:** See `/root/.claude/plans/parsed-chasing-grove.md`

### Phase 3: reCAPTCHA
- Google reCAPTCHA v2 integration
- Per-form toggle (Enable_Captcha__c field on Form__c)
- Protected custom settings for API keys (site key + secret key)
- Server-side verification in CaseFormController.submitForm()

### Phase 4: Advanced Features
- Embeddable JavaScript widget (for non-Salesforce sites)
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
│   ├── ErrorLoggerTest.cls
│   ├── FormAdminController.cls      # Phase 1
│   └── FormAdminControllerTest.cls  # Phase 1
├── lwc/
│   ├── formAdminApp/         # Phase 1 - Main admin container
│   └── formDetail/           # Phase 1 - Form editor
├── flexipages/
│   └── Form_Manager.flexipage-meta.xml  # Phase 1
├── tabs/
│   └── Form_Manager.tab-meta.xml        # Phase 1
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
- For preview mode, add `?preview=true` to bypass Active check

### File upload not showing
- Verify `Enable_File_Upload__c = true` on the Form__c record
- Check Guest User has Read access to `Enable_File_Upload__c` field

### Submission fails
- Check Error_Log__c for error details
- Verify Guest User has Create access to Case, ContentVersion, ContentDocumentLink
- Enable debug logs for the Guest User

### Form Manager tab not visible
- Assign the **Web_to_Case_Admin** permission set to your user
- Verify Form_Manager tab is set to Visible in the permission set

---

## Changelog

### v0.2.0 (2026-01-28) - Phase 1: Admin UI
- LWC Form Manager for creating/editing forms without Setup
- FormAdminController with CRUD operations (33 tests, 94%+ coverage)
- formAdminApp component with list view and delete modal
- formDetail component with inline field editing
- Clickable form names for quick editing
- Field reordering with up/down arrows
- URL hash routing for bookmarkable links
- Preview mode support (`?preview=true`)
- Form_Manager Lightning tab

### v0.1.0 (2026-01-28) - Phase 0: MVP
- Initial release
- Form__c, Form_Field__c, Error_Log__c custom objects
- CaseFormController with file attachment support
- CaseFormPage Visualforce page
- Basic styling and client-side validation
- Error logging utility

---

## Next Session Starting Point

**Status:** Phase 0 and Phase 1 complete. **Phase 2 planning complete.** Ready to implement.

**Detailed plan location:** `/root/.claude/plans/parsed-chasing-grove.md`

---

### Phase 2 Implementation Summary

**Research completed.** Key findings:
- Sites can be queried via SOQL but not created (need manual creation)
- Object/Field permissions CAN be set programmatically via ObjectPermissions/FieldPermissions
- Apex/VF access CANNOT be set programmatically on Guest Profile (must be manual with validation)

**Implementation order:**

1. **Apex Controller** (`SetupWizardController.cls`)
   ```
   Methods to implement:
   - checkPreconditions() - My Domain, admin perms, Sites enabled
   - getActiveSites() - SOQL on Site object
   - getSetupStatus(siteId) - Check current permission status
   - configurePermissions(siteId) - Set ObjectPermissions/FieldPermissions (idempotent)
   - validateConfiguration(siteId) - Check all perms including Apex/VF access
   - createSampleForm() - Create "Contact Support" form
   - getPublicUrl(siteId, formName) - Derive URL from Site object
   - getConfigSummary(siteId) - For diagnostics download
   ```

2. **Test Class** (`SetupWizardControllerTest.cls`)
   - Target 90%+ coverage
   - Test precondition checks, permission config, validation

3. **LWC Wizard** (`setupWizard/`)
   - 5-step progress indicator
   - Step 1: Precondition checks with pass/fail display
   - Step 2: Site selection with radio buttons, refresh button
   - Step 3: Security warning + auto-config with retry capability
   - Step 4: Manual instructions + validation button
   - Step 5: URL display, test link, sample form creation, diagnostics download

4. **Metadata**
   - `Setup_Wizard.flexipage-meta.xml`
   - `Setup_Wizard.tab-meta.xml`
   - Update permission set

**Key technical notes:**
- Use `with sharing` on all controllers
- Make permission config idempotent (safe to retry)
- Log errors to Error_Log__c
- Derive URLs dynamically from Site object (works with Enhanced Domains)

**Dev org:** `tilman.dietrich@gmail.com.dev` (alias: `devorg`)

**GitHub:** https://github.com/tilman-d/salesforce-webtocase
