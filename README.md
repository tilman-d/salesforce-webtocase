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
| **Phase 2** | Post-Install Setup Wizard | ✅ Complete |
| **Phase 3** | reCAPTCHA integration | 🔜 **Next up** |
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

## What's Built (Phase 2)

### Post-Install Setup Wizard
Access via the **Setup Wizard** tab or the **Web-to-Case Forms** app in the App Launcher.

**5-Step Wizard Flow:**
1. **Welcome** - Precondition checks (My Domain, admin permissions, Sites enabled)
2. **Select Site** - Choose from existing Sites or get instructions to create one
3. **Configure** - Auto-configure Guest User object/field permissions with security acknowledgment
4. **Verify** - Manual configuration instructions for Apex class and VF page access with validation
5. **Complete** - Create sample form, test form, view public URL, link to Form Manager

**Features:**
- Automatic detection of active Salesforce Sites
- One-click permission configuration for Guest User profile
- Support for both Enhanced Profile UI and Classic Profile UI instructions
- Validation to ensure all permissions are correctly configured
- Sample "Contact Support" form creation
- Dynamic public URL generation (works with Enhanced Domains)

### Apex Classes
- **SetupWizardController** - Site detection, permission configuration, validation, sample form creation
- **SetupWizardControllerTest** - Unit tests with coverage

### LWC Components
- **setupWizard** - Multi-step wizard with progress indicator

### Metadata
- **Setup_Wizard.flexipage-meta.xml** - Lightning App Page
- **Setup_Wizard.tab-meta.xml** - Navigation tab
- **Web_to_Case_Forms.app-meta.xml** - Lightning App (consolidates all functionality)

### Permission Set Updates
- Added SetupWizardController class access
- Added Setup_Wizard tab visibility
- Added Web_to_Case_Forms app visibility

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

### Phase 3: reCAPTCHA Integration (NEXT)

**Problem:** Public forms are vulnerable to spam and bot submissions. Without CAPTCHA protection, orgs may receive large volumes of junk cases.

**Solution:** Google reCAPTCHA v2 integration with per-form toggle.

**Planned Features:**
- Google reCAPTCHA v2 ("I'm not a robot" checkbox)
- Per-form toggle (`Enable_Captcha__c` field on Form__c)
- Protected Custom Settings for API keys (Site Key + Secret Key)
- Server-side verification in `CaseFormController.submitForm()`
- Admin UI in Form Manager for enabling/disabling per form
- Setup Wizard step for configuring reCAPTCHA keys

**Technical Approach:**
1. Add `Enable_Captcha__c` checkbox field to Form__c
2. Create `reCAPTCHA_Settings__c` Custom Setting (protected, hierarchy)
3. Add reCAPTCHA JavaScript to CaseFormPage
4. Modify CaseFormController to verify token server-side via Google API
5. Update Form Manager UI to show captcha toggle
6. Add reCAPTCHA key configuration to Setup Wizard

**Files to create/modify:**
- `reCAPTCHA_Settings__c.object-meta.xml` - Custom Setting for API keys
- `Form__c.Enable_Captcha__c.field-meta.xml` - New field
- `CaseFormController.cls` - Add server-side verification
- `caseFormScript.js` - Add reCAPTCHA widget integration
- `CaseFormPage.page` - Include reCAPTCHA script
- `formDetail` LWC - Add captcha toggle
- `setupWizard` LWC - Add reCAPTCHA configuration step (optional)

### Phase 4: Advanced Features
- Embeddable JavaScript widget (for non-Salesforce sites)
- Multi-file upload
- Custom field types (picklist, date)
- Form analytics/submission tracking

---

## Project Structure

```
force-app/main/default/
├── applications/
│   └── Web_to_Case_Forms.app-meta.xml   # Phase 2 - Lightning App
├── objects/
│   ├── Form__c/              # Form configuration
│   ├── Form_Field__c/        # Field definitions
│   └── Error_Log__c/         # Error logging
├── classes/
│   ├── CaseFormController.cls
│   ├── CaseFormControllerTest.cls
│   ├── ErrorLogger.cls
│   ├── ErrorLoggerTest.cls
│   ├── FormAdminController.cls          # Phase 1
│   ├── FormAdminControllerTest.cls      # Phase 1
│   ├── SetupWizardController.cls        # Phase 2
│   └── SetupWizardControllerTest.cls    # Phase 2
├── lwc/
│   ├── formAdminApp/         # Phase 1 - Main admin container
│   ├── formDetail/           # Phase 1 - Form editor
│   └── setupWizard/          # Phase 2 - Setup wizard
├── flexipages/
│   ├── Form_Manager.flexipage-meta.xml  # Phase 1
│   └── Setup_Wizard.flexipage-meta.xml  # Phase 2
├── tabs/
│   ├── Form_Manager.tab-meta.xml        # Phase 1
│   └── Setup_Wizard.tab-meta.xml        # Phase 2
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

### v0.3.0 (2026-01-28) - Phase 2: Setup Wizard
- 5-step post-install setup wizard
- Automatic Guest User permission configuration
- Site detection and selection
- Manual configuration instructions (Enhanced + Classic Profile UI)
- Configuration validation
- Sample form creation
- Dynamic public URL generation
- "Web-to-Case Forms" Lightning App in App Launcher
- SetupWizardController with unit tests
- Setup_Wizard Lightning tab

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

**Status:** Phase 0, Phase 1, and Phase 2 complete. **Ready for Phase 3: reCAPTCHA Integration.**

**Dev org:** `tilman.dietrich@gmail.com.dev` (alias: `devorg`)

**GitHub:** https://github.com/tilman-d/salesforce-webtocase

---

### Phase 3 Implementation Summary

**Goal:** Add Google reCAPTCHA v2 to prevent spam/bot submissions on public forms.

**Implementation order:**

1. **Custom Setting** (`reCAPTCHA_Settings__c`)
   - Protected hierarchy Custom Setting
   - Fields: Site_Key__c, Secret_Key__c
   - Allows different keys per org/profile if needed

2. **Form__c Field** (`Enable_Captcha__c`)
   - Checkbox field to toggle reCAPTCHA per form
   - Default: false (opt-in)

3. **Frontend Integration**
   - Add Google reCAPTCHA script to CaseFormPage
   - Render widget when form has captcha enabled
   - Pass token with form submission

4. **Backend Verification**
   - Modify CaseFormController.submitForm()
   - Verify reCAPTCHA token via Google API (HTTP callout)
   - Reject submission if verification fails
   - Add Remote Site Setting for google.com

5. **Admin UI Updates**
   - Add captcha toggle to formDetail LWC
   - Add Field Permission for Enable_Captcha__c

6. **Setup Wizard Updates** (optional)
   - Add step for configuring reCAPTCHA keys
   - Or separate admin page for key management

**Key technical notes:**
- Use Named Credential or Remote Site Setting for Google API
- Store Secret Key securely (Custom Setting, not exposed to client)
- Handle verification timeout gracefully
- Consider rate limiting on verification failures
