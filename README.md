# Web-to-Case with Attachments

A Salesforce app that lets you create public web forms that submit Cases with file attachments. Built for the AppExchange.

## Why This Exists

Salesforce's native Web-to-Case doesn't support file attachments. This app solves that problem with:
- Configurable forms stored as custom objects
- Public Visualforce page for form rendering
- File attachments via ContentVersion/ContentDocumentLink
- LWC Admin UI for managing forms without using Setup
- Google reCAPTCHA v2 for spam protection
- Error logging for debugging

---

## Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 0** | MVP - Core form submission | ✅ Complete |
| **Phase 1** | Admin UI (LWC form builder) | ✅ Complete |
| **Phase 2** | Post-Install Setup Wizard | ✅ Complete |
| **Phase 3** | reCAPTCHA integration | ✅ Complete |
| **Phase 4** | Embeddable widget, multi-file upload | 🔜 **Next up** |

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

## What's Built (Phase 3)

### Google reCAPTCHA v2 Integration
Protects public forms from spam and bot submissions with "I'm not a robot" checkbox verification.

**Features:**
- Per-form CAPTCHA toggle (`Enable_Captcha__c` field on Form__c)
- Protected Custom Setting for API keys (`reCAPTCHA_Settings__c`)
- Client-side reCAPTCHA widget rendering
- Server-side token verification via Google API
- Graceful error handling with user-friendly messages
- Admin UI toggle in Form Manager

### Custom Setting
- **reCAPTCHA_Settings__c** - Protected hierarchy Custom Setting
  - `Site_Key__c` - Public key for widget rendering
  - `Secret_Key__c` - Private key for server-side verification

### Form__c Field
- **Enable_Captcha__c** - Checkbox to enable/disable CAPTCHA per form

### Remote Site Setting
- **Google_reCAPTCHA** - Allows callouts to `https://www.google.com` for token verification

### Updated Components
- **CaseFormController.cls** - Added `verifyCaptcha()` method, `getCaptchaSiteKey()`, `getCaptchaEnabled()`
- **CaseFormPage.page** - Conditionally loads reCAPTCHA script and renders widget
- **caseFormScript.js** - Handles CAPTCHA token extraction and submission
- **caseFormStyles.css** - Styling for CAPTCHA widget and error messages
- **formDetail LWC** - Added "Enable CAPTCHA" toggle in form settings

### Permission Set Updates
- Added `Enable_Captcha__c` field permission (Read/Edit)

### Test Coverage
- **CaseFormControllerTest** - 22 tests including 9 CAPTCHA-specific tests with HTTP mocks
- 88% code coverage on CaseFormController

---

## Manual Testing Checklist (Phase 3)

Use this checklist to verify reCAPTCHA integration in your org:

### 1. Configure reCAPTCHA API Keys

- [ ] Go to [Google reCAPTCHA Admin Console](https://www.google.com/recaptcha/admin)
- [ ] Create a new site with reCAPTCHA v2 "I'm not a robot" checkbox
- [ ] Add your Salesforce Site domain (e.g., `yourorg.my.salesforce-sites.com`)
- [ ] Copy the **Site Key** and **Secret Key**

### 2. Add Keys to Salesforce

- [ ] In Salesforce, go to **Setup** → **Custom Settings**
- [ ] Find **reCAPTCHA Settings** and click **Manage**
- [ ] Click **New** (at org level)
- [ ] Enter your **Site Key** and **Secret Key**
- [ ] Click **Save**

### 3. Create a Test Form with CAPTCHA

- [ ] Go to **Form Manager** tab
- [ ] Click **New Form** or edit an existing form
- [ ] Check the **Enable CAPTCHA** checkbox
- [ ] Add at least one required field (e.g., Name, Email, Subject)
- [ ] Check **Active**
- [ ] Click **Save**

### 4. Test the Public Form

- [ ] Click **View Live** to open the form in a new tab
- [ ] Verify the reCAPTCHA widget ("I'm not a robot") appears below the form fields
- [ ] **Test 1: Submit without CAPTCHA**
  - [ ] Fill in all required fields
  - [ ] Do NOT click the CAPTCHA checkbox
  - [ ] Click Submit
  - [ ] Verify error message: "Please complete the CAPTCHA verification."
- [ ] **Test 2: Submit with CAPTCHA**
  - [ ] Fill in all required fields
  - [ ] Click the reCAPTCHA checkbox (wait for green checkmark)
  - [ ] Click Submit
  - [ ] Verify success message with case number

### 5. Verify Case Creation

- [ ] Go to **Cases** tab in Salesforce
- [ ] Find the newly created case
- [ ] Verify the case fields match your form submission

### 6. Test Form WITHOUT CAPTCHA

- [ ] Create or edit a form with **Enable CAPTCHA** unchecked
- [ ] View the form publicly
- [ ] Verify NO reCAPTCHA widget appears
- [ ] Submit the form and verify it works without CAPTCHA

### 7. Test Admin UI

- [ ] Go to **Form Manager** tab
- [ ] Verify the **Enable CAPTCHA** checkbox appears in form settings
- [ ] Verify the help text explains reCAPTCHA requirements
- [ ] Toggle CAPTCHA on/off and save - verify it persists

### Troubleshooting

| Issue | Solution |
|-------|----------|
| reCAPTCHA widget doesn't appear | Check that `reCAPTCHA_Settings__c` has Site Key configured |
| "CAPTCHA verification failed" on submit | Verify Secret Key is correct in Custom Settings |
| Form hangs on submit | Check browser console for errors; verify Remote Site Setting exists |
| Error: "Unauthorized endpoint" | Add Remote Site Setting for `https://www.google.com` |

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
    Max_File_Size_MB__c = 10,
    Enable_Captcha__c = true  // Enable CAPTCHA
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

**Field Permissions (Form__c):** Read access to Description__c, Enable_File_Upload__c, Max_File_Size_MB__c, Success_Message__c, Enable_Captcha__c

**Field Permissions (Form_Field__c):** Read access to Required__c

**Apex Class Access:** CaseFormController, ErrorLogger

**VF Page Access:** CaseFormPage

### 5. Configure reCAPTCHA (Phase 3)
1. Get API keys from [Google reCAPTCHA Admin](https://www.google.com/recaptcha/admin)
2. Setup → Custom Settings → reCAPTCHA Settings → Manage → New
3. Enter Site Key and Secret Key

### 6. Test
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
   - **Enable CAPTCHA**: Require reCAPTCHA verification (Phase 3)
4. Add fields in the **Form Fields** section
5. Click **Save**
6. Use **View Live** to preview the form

---

## Roadmap

### Phase 4: Advanced Features (NEXT)
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
│   ├── Form__c/                         # Form configuration
│   │   └── fields/
│   │       └── Enable_Captcha__c        # Phase 3
│   ├── Form_Field__c/                   # Field definitions
│   ├── Error_Log__c/                    # Error logging
│   └── reCAPTCHA_Settings__c/           # Phase 3 - API keys
│       └── fields/
│           ├── Site_Key__c
│           └── Secret_Key__c
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
│   ├── formAdminApp/                    # Phase 1 - Main admin container
│   ├── formDetail/                      # Phase 1 - Form editor (+ CAPTCHA toggle)
│   └── setupWizard/                     # Phase 2 - Setup wizard
├── flexipages/
│   ├── Form_Manager.flexipage-meta.xml  # Phase 1
│   └── Setup_Wizard.flexipage-meta.xml  # Phase 2
├── tabs/
│   ├── Form_Manager.tab-meta.xml        # Phase 1
│   └── Setup_Wizard.tab-meta.xml        # Phase 2
├── pages/
│   └── CaseFormPage.page                # + reCAPTCHA widget (Phase 3)
├── staticresources/
│   ├── caseFormStyles.css               # + CAPTCHA styles (Phase 3)
│   └── caseFormScript.js                # + CAPTCHA handling (Phase 3)
├── remoteSiteSettings/
│   └── Google_reCAPTCHA.remoteSite-meta.xml  # Phase 3
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

### reCAPTCHA not showing (Phase 3)
- Verify `Enable_Captcha__c = true` on the Form__c record
- Check that `reCAPTCHA_Settings__c` has a valid Site Key
- Guest User needs Read access to `Enable_Captcha__c` field

### CAPTCHA verification fails (Phase 3)
- Verify Secret Key is correct in `reCAPTCHA_Settings__c`
- Check Remote Site Setting `Google_reCAPTCHA` is active
- Review Error_Log__c for detailed error messages

---

## Changelog

### v0.4.0 (2026-01-28) - Phase 3: reCAPTCHA Integration
- Google reCAPTCHA v2 "I'm not a robot" checkbox integration
- Per-form CAPTCHA toggle (`Enable_Captcha__c` field)
- `reCAPTCHA_Settings__c` protected Custom Setting for API keys
- Server-side token verification via Google API
- Client-side CAPTCHA widget with error handling
- Admin UI "Enable CAPTCHA" toggle in Form Manager
- Remote Site Setting for Google API callouts
- 9 new unit tests for CAPTCHA scenarios (22 total in CaseFormControllerTest)
- 88% code coverage on CaseFormController

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

**Status:** Phases 0-3 complete. **Ready for Phase 4: Advanced Features.**

**Dev org:** `tilman.dietrich@gmail.com.dev` (alias: `devorg`)

**GitHub:** https://github.com/tilman-d/salesforce-webtocase

---

### Phase 4 Implementation Ideas

**Embeddable JavaScript Widget:**
- Generate embeddable `<script>` tag for external websites
- Cross-domain form submission via postMessage or CORS
- Customizable styling via CSS variables

**Multi-file Upload:**
- Allow multiple file attachments per submission
- Drag-and-drop file upload UI
- File type and size validation per file

**Custom Field Types:**
- Picklist fields with configurable options
- Date picker fields
- Checkbox fields
- Phone number formatting

**Form Analytics:**
- Track form views, submissions, abandonment
- Success/error rate metrics
- Time-to-submit analytics
