# Web-to-Case with Attachments

A Salesforce app that lets you create public web forms that submit Cases with file attachments. Built for the AppExchange.

---

## TODO: AppExchange Release Checklist

### Must Do (Before Submission)

- [x] **Increase test coverage for `WebToCaseNonceService` (51% → 81%)**
  - Nonce generation/validation round-trip, one-time use, expiry, formId/origin mismatch, case authorization, Platform Cache paths
- [x] **Increase test coverage for `SetupWizardController` (50% → 86%)**
  - Real Site permission checking, configurePermissions, getPublicUrl, getConfigSummary, getFullStatus, saveDefaultSite, CRUD denial, no Guest User paths
- [ ] **Register namespace prefix** (manual step in Salesforce UI)
  - Go to Setup → Package Manager → Edit → register a namespace prefix
  - Update `sfdx-project.json` with the namespace
  - This is a one-time manual step — cannot be scripted
- [ ] **Create managed package** in packaging org
  - Add all package components (see "AppExchange Package Metadata" section below)
  - Exclude org-specific metadata (CORS origins, CSP sites, Sites) — already in `.forceignore`
- [ ] **Upload package version** and submit for AppExchange security review

### Done (This Session)

- [x] Security fixes deployed (IDOR on `uploadFileChunk`, nonce replay, SOQL injection, chunk validation)
- [x] `checkUploadStatus` IDOR check added (authorization required before status polling)
- [x] `authorizeCaseForUpload` made conditional on `Enable_File_Upload__c`
- [x] SOQL injection false positives resolved (converted dynamic SOQL to static queries)
- [x] Empty catch blocks fixed (added `System.debug` logging)
- [x] ESLint violations fixed in `caseFormScript.js` and `caseFormWidget.js`
- [x] Org-specific metadata removed (CORS origins, CSP trusted sites, Site config)
- [x] `.forceignore` created to prevent re-pulling org-specific metadata
- [x] `WebToCaseNonceService` test coverage: 51% → 81% (14 new tests)
- [x] `SetupWizardController` test coverage: 50% → 86% (12 new tests)
- [x] 257/257 tests passing

### Scanner Notes

- **0 Critical/High** violations on custom code (Apex SOQL injection + empty catch blocks fixed, JS ESLint clean)
- **59 `pmd:ApexCRUDViolation`** remaining — all false positives (PMD can't detect manual `assertAccessible`/`assertCreateable`/`stripInaccessible` enforcement). Won't fail security review.
- **19 violations** in `imageCompression.js` — third-party minified library, not our code

---

## 🧪 MANUAL TESTING REQUIRED: Custom HTML Connect Mode + Extended CSS Variables (v0.6.0)

The following items need manual verification in the dev org:

### Connect Mode (`WebToCaseForm.connect()`)
- [x] Create a standalone HTML page with a custom form layout
- [x] Include the widget script and call `WebToCaseForm.connect()` with correct apiBase/formName
- [x] Verify form submission creates a Case with correct field values
- [ ] Verify file upload works via `fileInputSelector` option
- [ ] Verify CAPTCHA renders in the user-provided container (if enabled)
- [x] Verify validation errors appear in the user's error container and use `aria-invalid`
- [x] Verify success state hides the form and shows the success container with case number in `[data-wtc-case-number]`
- [ ] Verify `destroy()` cleans up event listeners (test re-initialization in SPA-like scenario)
- [ ] Verify console warnings appear for missing `name` attributes on required fields

### Extended CSS Variables (Widget Mode)
- [x] Embed the widget on a test page and set `--wtc-container-max-width`, `--wtc-container-padding` — verify they take effect
- [x] Test title variables: `--wtc-title-font-size`, `--wtc-title-font-weight`, `--wtc-title-margin`
- [x] Test description variables: `--wtc-description-color`, `--wtc-description-font-size`
- [x] Test label variables: `--wtc-label-font-size`, `--wtc-label-font-weight`, `--wtc-label-color`
- [x] Test input variables: `--wtc-input-padding`, `--wtc-input-font-size`
- [x] Test field gap: `--wtc-field-gap`
- [x] Test submit button: `--wtc-submit-color`, `--wtc-submit-background`, `--wtc-submit-padding`, `--wtc-submit-font-size`, `--wtc-submit-border-radius`
- [x] Test success/error: `--wtc-success-background`, `--wtc-success-border`, `--wtc-error-background`, `--wtc-error-border`

### Admin UI (Embed Code Section)
- [ ] Verify scoped tabs (Widget / Custom HTML / iframe) render with light blue active background
- [ ] Verify "Generate Embed Code" button is required before tabs appear
- [ ] Verify tabs show immediately when loading a saved form with existing allowed domains
- [ ] Verify Custom HTML tab generates correct HTML snippet with actual form fields
- [ ] Verify Custom HTML tab generates correct CSS snippet scoped to form ID
- [ ] Verify Custom HTML tab generates correct JS snippet with `connect()` call
- [ ] Verify all Copy buttons work in all three tabs

### Regression
- [x] Verify existing `WebToCaseForm.render()` widget still works identically after the mixin refactor
- [x] Verify iframe embed still works

---

## 🧪 MANUAL TESTING REQUIRED: reCAPTCHA Issues

> **Note:** reCAPTCHA UI is hidden for v1 MVP (v0.7.0). These tests apply only after re-enabling for v2.

### reCAPTCHA v3 Testing (deferred to v2)
- [ ] Create reCAPTCHA v3 keys at Google Admin Console (select "v3")
- [ ] Configure v3 in Setup Wizard (select "v3 Score-based" type)
- [ ] Test form submission with v3 - verify invisible badge appears
- [ ] Verify low-score submissions are blocked (use VPN/incognito to simulate bot-like behavior)
- [ ] Test switching between v2 Checkbox, v2 Invisible, and v3 Score-based

---

## Quick Status

| | |
|---|---|
| **Version** | v0.7.2 |
| **Phases Complete** | 0-4 (MVP, Admin UI, Setup Wizard, reCAPTCHA, Embeddable Widget) |
| **Next Up** | AppExchange v1 submission / Phase 5 |
| **Dev Org** | `devorg` (tilman.dietrich@gmail.com.dev) |
| **GitHub** | https://github.com/tilman-d/salesforce-webtocase |
| **Last Change** | Fix Setup Wizard permission config error for required fields |

---

## Why This Exists

Salesforce's native Web-to-Case doesn't support file attachments. This app solves that problem with:
- Configurable forms stored as custom objects
- Public Visualforce page for form rendering
- File attachments via ContentVersion/ContentDocumentLink
- LWC Admin UI for managing forms without using Setup
- Google reCAPTCHA v2/v3 for spam protection (hidden in v1 MVP, re-enable for v2)
- Error logging for debugging

---

## Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 0** | MVP - Core form submission | ✅ Complete |
| **Phase 1** | Admin UI (LWC form builder) | ✅ Complete |
| **Phase 2** | Post-Install Setup Wizard | ✅ Complete |
| **Phase 3** | reCAPTCHA integration | ✅ Complete |
| **Phase 4** | Embeddable widget for external websites | ✅ Complete |
| **Phase 5** | Multi-file upload, custom field types | 🔜 **Next up** |

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
- List all forms with field counts and created date
- **Sortable columns** - click column headers to sort (Form Name, Title, Fields, Active, Created)
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

**5-Step Wizard Flow (v1 MVP):**
1. **Welcome** - Precondition checks (My Domain, admin permissions, Sites enabled)
2. **Select Site** - Choose from existing Sites or get instructions to create one
3. **Configure** - Auto-configure Guest User object/field permissions with security acknowledgment
4. **Verify** - Manual configuration instructions for Apex class and VF page access with validation
5. **Complete** - Simplified 2-box layout:
   - "Test Your Setup" box: Sample form creation (optional), Test Form button, Public URL with copy
   - "What's Next" box: Link to Form Manager

> **Note:** The reCAPTCHA step (previously step 5) is hidden for v1 MVP. All reCAPTCHA code remains intact — uncomment in `setupWizard.js` to restore the 6-step flow for v2.

**Features:**
- Automatic detection of active Salesforce Sites
- One-click permission configuration for Guest User profile
- Support for both Enhanced Profile UI and Classic Profile UI instructions
- Validation to ensure all permissions are correctly configured
- **reCAPTCHA configuration UI** - Enter Site Key and Secret Key without Anonymous Apex (hidden in v1 MVP)
- Sample "Contact Support" form creation
- Dynamic public URL generation (works with Enhanced Domains)

### Apex Classes
- **SetupWizardController** - Site detection, permission configuration, validation, sample form creation, reCAPTCHA settings management
- **SetupWizardControllerTest** - Unit tests with coverage (41 tests)

### LWC Components
- **setupWizard** - Multi-step wizard with progress indicator
- **setupStatus** - Configuration Status Dashboard (embedded in Setup Wizard page, hidden when unconfigured, auto-refreshes via LMS when wizard completes)

### Metadata
- **Setup_Wizard.flexipage-meta.xml** - Lightning App Page
- **Setup_Wizard.tab-meta.xml** - Navigation tab
- **Web_to_Case_Forms.app-meta.xml** - Lightning App (consolidates all functionality)
- **SetupStatusRefresh.messageChannel-meta.xml** - LMS channel for wizard→dashboard communication

### Permission Set Updates
- Added SetupWizardController class access
- Added Setup_Wizard tab visibility
- Added Web_to_Case_Forms app visibility

---

## What's Built (Phase 3)

### Google reCAPTCHA v2/v3 Integration

> **v1 MVP Note:** All reCAPTCHA admin UI surfaces are hidden for v1 AppExchange release to reduce onboarding friction and external dependencies. All code remains intact and conditional. See [Re-enabling reCAPTCHA for v2](#re-enabling-recaptcha-for-v2) below.

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

## What's Built (Phase 4)

### Embeddable Widget for External Websites
Allows users to embed Web-to-Case forms on external websites using a `<script>` tag.

**Three Embed Modes:**

#### Mode 1: Inline Widget (Recommended)
- Uses Shadow DOM for CSS isolation
- Customizable via 28 CSS variables (container, title, description, labels, inputs, submit button, success/error)
- Form rendered directly in the host page

#### Mode 2: Custom HTML Connect Mode
- `WebToCaseForm.connect()` binds submission logic to user's own HTML form
- No Shadow DOM, no rendered HTML — full design control
- Validates against form config using `aria-invalid` attributes
- Collects only config-defined fields by `name` attribute
- Supports file upload, CAPTCHA, chunked uploads, and all existing features
- `destroy()` method for SPA re-initialization
- Init-time console warnings for missing required field inputs

#### Mode 3: iframe Embed
- Full DOM isolation
- Automatic height resizing via postMessage
- Best for sites with strict CSP policies

### REST API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/webtocase/v1/form/{formName}` | Get form configuration + nonce |
| POST | `/webtocase/v1/submit` | Submit form data |
| POST | `/webtocase/v1/upload-chunk` | Upload file chunk |
| OPTIONS | `/*` | CORS preflight |

### Security Features
- **Origin validation**: Strict domain allowlist per form
- **One-time nonce**: Prevents replay attacks (15-min TTL)
- **Rate limiting**: 100 submissions/hour per origin
- **Field allowlist**: Server ignores unknown fields

### New Files

**Apex Classes:**
- `WebToCaseRestAPI.cls` - REST API with CORS support
- `WebToCaseNonceService.cls` - Nonce generation/validation
- `WebToCaseRateLimiter.cls` - Rate limiting logic
- `WebToCaseRestAPITest.cls` - Unit tests

**Static Resources:**
- `caseFormWidget.js` - Embeddable widget script

**Custom Objects:**
- `Rate_Limit_Counter__c` - Tracks rate limits per origin

**New Fields:**
- `Form__c.Allowed_Domains__c` - Newline-separated domain allowlist

### Admin UI Updates
- **Embed Code section** in Form Detail with:
  - Allowed Domains textarea with "Generate Embed Code" confirmation button
  - SLDS scoped tabs: **Widget** | **Custom HTML** | **iframe**
  - Widget tab: Inline script snippet + CSS variables snippet
  - Custom HTML tab: Generated HTML/CSS/JS snippets from actual form fields
  - iframe tab: iframe embed snippet
  - Copy buttons for all code snippets
  - reCAPTCHA domain warning (above tabs, applies to all methods)

### CSS Variables for Styling (28 variables)

```css
#support-form {
  /* Base */
  --wtc-primary-color: #0176d3;
  --wtc-font-family: system-ui, -apple-system, sans-serif;
  --wtc-text-color: #181818;
  --wtc-border-radius: 4px;
  --wtc-error-color: #c23934;
  --wtc-success-color: #2e844a;
  /* Container */
  --wtc-container-max-width: 100%;
  --wtc-container-padding: 0;
  /* Title */
  --wtc-title-font-size: 1.5rem;
  --wtc-title-font-weight: 600;
  --wtc-title-margin: 0 0 8px 0;
  /* Description */
  --wtc-description-color: #666;
  --wtc-description-font-size: 0.875rem;
  /* Labels */
  --wtc-label-font-size: 0.875rem;
  --wtc-label-font-weight: 500;
  --wtc-label-color: var(--wtc-text-color);
  /* Inputs */
  --wtc-input-border: 1px solid #c9c9c9;
  --wtc-input-background: #ffffff;
  --wtc-input-padding: 10px 12px;
  --wtc-input-font-size: 1rem;
  /* Field layout */
  --wtc-field-gap: 20px;
  /* Submit button */
  --wtc-submit-color: #fff;
  --wtc-submit-background: var(--wtc-primary-color);
  --wtc-submit-padding: 12px 24px;
  --wtc-submit-font-size: 1rem;
  --wtc-submit-border-radius: var(--wtc-border-radius);
  /* Success/Error */
  --wtc-success-background: #d4edda;
  --wtc-success-border: 1px solid #c3e6cb;
  --wtc-error-background: #f8d7da;
  --wtc-error-border: 1px solid #f5c6cb;
}
```

---

## Embedding Forms on External Websites

### Quick Start

1. **Configure allowed domains** in Form Manager:
   - Edit your form
   - Go to "Embed Code" section
   - Add your website domain (e.g., `example.com`)
   - Save the form

2. **Add embed code to your website**:

```html
<div id="support-form"></div>
<script src="https://yoursite.salesforce-sites.com/support/resource/caseFormWidget"></script>
<script>
  WebToCaseForm.render({
    formName: 'support',
    containerId: 'support-form',
    apiBase: 'https://yoursite.salesforce-sites.com/support/services/apexrest',
    onSuccess: function(caseNumber) {
      console.log('Case created:', caseNumber);
    },
    onError: function(error) {
      console.error('Error:', error);
    }
  });
</script>
```

### Custom HTML (Connect Mode)

Use `WebToCaseForm.connect()` for full control over form HTML and styling:

```html
<form id="wtc-support">
  <div>
    <label for="SuppliedName">Your Name *</label>
    <input type="text" id="SuppliedName" name="SuppliedName" required />
  </div>
  <div>
    <label for="SuppliedEmail">Email *</label>
    <input type="email" id="SuppliedEmail" name="SuppliedEmail" required />
  </div>
  <div>
    <label for="Subject">Subject *</label>
    <input type="text" id="Subject" name="Subject" required />
  </div>
  <div>
    <label for="Description">Message *</label>
    <textarea id="Description" name="Description" required></textarea>
  </div>
  <div id="wtc-error" hidden></div>
  <button type="submit">Submit</button>
</form>

<div id="wtc-success" hidden>
  <p>Your request has been submitted successfully.</p>
  <p>Reference: <span data-wtc-case-number></span></p>
</div>

<script src="https://yoursite.salesforce-sites.com/support/resource/caseFormWidget"></script>
<script>
  WebToCaseForm.connect({
    formName: 'support',
    formSelector: '#wtc-support',
    apiBase: 'https://yoursite.salesforce-sites.com/support/services/apexrest',
    errorContainerId: 'wtc-error',
    successContainerId: 'wtc-success',
    onSuccess: function(caseNumber) {
      console.log('Case created:', caseNumber);
    },
    onError: function(error) {
      console.error('Error:', error);
    }
  });
</script>
```

Input `name` attributes must match Case field API names from your form config. You can rearrange elements, add classes, and style freely — the script only touches elements it needs.

### iframe Alternative

Use iframe if you need full DOM isolation:

```html
<iframe
  src="https://yoursite.salesforce-sites.com/support/apex/CaseFormPage?form=support&embed=1"
  style="width:100%; border:none; min-height:500px;"
  id="wtc-frame">
</iframe>
<script>
  window.addEventListener('message', function(e) {
    if (e.data && e.data.type === 'wtc:resize') {
      document.getElementById('wtc-frame').style.height = e.data.height + 'px';
    }
  });
</script>
```

### CSP Requirements

Add these to your Content-Security-Policy if using the inline widget:

```
script-src: https://yoursite.salesforce-sites.com
connect-src: https://yoursite.salesforce-sites.com
frame-src: https://www.google.com https://yoursite.salesforce-sites.com
```

### reCAPTCHA Setup for Embedded Forms

If your form uses CAPTCHA, add your embedding domain to Google reCAPTCHA:

1. Go to [Google reCAPTCHA Admin Console](https://www.google.com/recaptcha/admin)
2. Select your reCAPTCHA site
3. Add your embedding domain (e.g., `example.com`) to the allowed domains list

### Troubleshooting Embedded Forms

| Issue | Solution |
|-------|----------|
| "Origin not allowed" error | Add your domain to Allowed Domains in Form Manager |
| CORS errors | Verify the apiBase URL is correct |
| CAPTCHA not loading | Add your domain to Google reCAPTCHA allowed domains |
| Form not rendering | Check browser console for JavaScript errors |
| Rate limit exceeded | Wait 1 hour or contact the form administrator |

---

## Manual Testing Checklist (Phase 3)

> **v1 MVP Note:** reCAPTCHA admin UI is hidden in v0.7.0. These tests apply only after re-enabling for v2 (see changelog).

Use this checklist to verify reCAPTCHA integration in your org:

### 1. Configure reCAPTCHA API Keys

- [ ] Go to [Google reCAPTCHA Admin Console](https://www.google.com/recaptcha/admin)
- [ ] Create a new site with reCAPTCHA v2 "I'm not a robot" checkbox
- [ ] Add your Salesforce Site domain (e.g., `yourorg.my.salesforce-sites.com`)
- [ ] Copy the **Site Key** and **Secret Key**

### 2. Add Keys to Salesforce (via Setup Wizard)

- [ ] Go to **Setup Wizard** tab (or run the wizard from App Launcher → "Web-to-Case Forms")
- [ ] If you already completed setup, navigate to Step 5 (reCAPTCHA)
- [ ] Enter your **Site Key** and **Secret Key**
- [ ] Click **Save reCAPTCHA Settings**
- [ ] Proceed to Complete step

**Alternative (Anonymous Apex):**
```apex
reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
settings.Site_Key__c = 'YOUR_SITE_KEY_HERE';
settings.Secret_Key__c = 'YOUR_SECRET_KEY_HERE';
upsert settings;
```

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
    Enable_Captcha__c = true  // Enable CAPTCHA
    // Note: File limits are fixed (Images: 25MB auto-compressed, Documents: 4MB)
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

**Field Permissions (Form__c):** Read access to Description__c, Enable_File_Upload__c, Success_Message__c, Enable_Captcha__c

**Field Permissions (Form_Field__c):** Read access to Required__c

**Apex Class Access:** CaseFormController, ErrorLogger

**VF Page Access:** CaseFormPage

### 5. Configure reCAPTCHA (Phase 3) — *Deferred in v1 MVP*
> reCAPTCHA admin UI is hidden in v0.7.0. To enable, see [Re-enabling reCAPTCHA for v2](#re-enabling-recaptcha-for-v2) in the changelog.

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
   - **Enable CAPTCHA**: Require reCAPTCHA verification (Phase 3, hidden in v1 MVP)
4. Add fields in the **Form Fields** section
5. Click **Save**
6. Use **View Live** to preview the form

---

## Roadmap

### Phase 5: Advanced Features (NEXT)
- Multi-file upload (drag & drop)
- Custom field types (picklist, date, checkbox)
- Form analytics/submission tracking
- Email notifications on submission

---

## Project Structure

```
force-app/main/default/
├── applications/
│   └── Web_to_Case_Forms.app-meta.xml   # Phase 2 - Lightning App
├── cachePartitions/
│   └── WebToCase.cachePartition-meta.xml # Platform Cache for nonces
├── # corsWhitelistOrigins/ — removed (org-specific, excluded via .forceignore)
├── # cspTrustedSites/ — removed (org-specific, excluded via .forceignore)
├── objects/
│   ├── Form__c/                         # Form configuration
│   │   └── fields/
│   │       ├── Enable_Captcha__c        # Phase 3
│   │       ├── Site_Id__c               # URL Display Feature
│   │       ├── Allowed_Domains__c       # Phase 4 - Embed allowlist
│   │       └── Default_Case_Values__c   # JSON defaults for hidden Case fields
│   ├── Form_Field__c/                   # Field definitions
│   ├── Error_Log__c/                    # Error logging
│   ├── Rate_Limit_Counter__c/           # Phase 4 - Rate limiting
│   └── reCAPTCHA_Settings__c/           # Phase 3 - API keys + Site settings
│       └── fields/
│           ├── Site_Key__c
│           ├── Secret_Key__c
│           ├── Captcha_Type__c
│           ├── Score_Threshold__c
│           ├── Default_Site_Id__c       # URL Display Feature
│           └── Default_Site_Base_Url__c # URL Display Feature
├── classes/
│   ├── CaseDefaultFieldConfig.cls       # Shared allowlist for default Case fields
│   ├── CaseFormController.cls
│   ├── CaseFormControllerTest.cls
│   ├── ErrorLogger.cls
│   ├── ErrorLoggerTest.cls
│   ├── FileAssemblyQueueable.cls        # Async chunk assembly (4MB support)
│   ├── FileAssemblyQueueableTest.cls
│   ├── FormAdminController.cls          # Phase 1
│   ├── FormAdminControllerTest.cls      # Phase 1
│   ├── SetupWizardController.cls        # Phase 2
│   ├── SetupWizardControllerTest.cls    # Phase 2
│   ├── WebToCaseRestAPI.cls             # Phase 4 - REST endpoints
│   ├── WebToCaseNonceService.cls        # Phase 4 - Nonce management
│   ├── WebToCaseRateLimiter.cls         # Phase 4 - Rate limiting
│   └── WebToCaseRestAPITest.cls         # Phase 4 - Tests
├── messageChannels/
│   └── SetupStatusRefresh.messageChannel-meta.xml  # LMS channel
├── lwc/
│   ├── formAdminApp/                    # Phase 1 - Main admin container
│   ├── formDetail/                      # Phase 1 - Form editor (+ CAPTCHA toggle)
│   ├── setupStatus/                     # Configuration Status Dashboard (+ LMS subscriber)
│   └── setupWizard/                     # Phase 2 - Setup wizard (+ LMS publisher)
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
│   ├── caseFormScript.js                # + compression, validation, postMessage
│   ├── caseFormWidget.js                # Phase 4 - Embeddable widget
│   └── imageCompression.js              # browser-image-compression library
├── remoteSiteSettings/
│   └── Google_reCAPTCHA.remoteSite-meta.xml  # Phase 3
├── # sites/ — removed (org-specific, excluded via .forceignore)
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

### v0.7.2 (2026-02-11) - Fix Setup Wizard Guest User Permission Error
Fixed "INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST" error when clicking "Configure Permissions" in the Setup Wizard (Step 3).

**Root cause:** `Error_Log__c.Timestamp__c` is a required field (`<required>true</required>`). Salesforce automatically grants FLS (Read/Edit) on required fields to all profiles, so they don't appear in the `FieldPermissions` restricted picklist. The wizard was trying to upsert a `FieldPermissions` record for this field, which Salesforce rejected.

**Fix:** Removed `Timestamp__c` from the `REQUIRED_FIELD_READ` map in `SetupWizardController` — no FLS configuration needed for required fields.

### v0.7.1 (2026-02-10) - Test Coverage for AppExchange Submission
Increased test coverage for the two classes that were below the 75% AppExchange threshold.

**WebToCaseNonceService: 51% → 81%** (14 new tests in `WebToCaseRestAPITest`):
- Nonce generate + validate/consume round-trip, one-time use enforcement
- Validation failures: formId mismatch, origin mismatch, expired nonce
- Blank origin matching (nonce with blank origin accepts any requester)
- Multiple independent nonces, empty allowedFields edge case
- Case upload authorization: full round-trip, blank/null IDs, non-authorized case
- Platform Cache code paths (generate, validate, authorize, check via cache)
- `isCacheAvailable()` cached result path, `NonceData` wrapper defaults

**SetupWizardController: 50% → 86%** (12 new tests in `SetupWizardControllerTest`):
- Real Site tests covering private helpers: `checkObjectPermission`, `checkFieldPermission`, `checkApexAccess`, `checkVfPageAccess`, `configureObjectPermission`, `configureFieldPermission`, `getSiteBaseUrl`
- `getSetupStatus`, `configurePermissions`, `validateConfiguration`, `getPublicUrl`, `getConfigSummary`, `getFullStatus`, `saveDefaultSite` — all with real active Site
- CRUD denial for `saveDefaultSite` and `configurePermissions`
- No Guest User error paths for `getSetupStatus` and `configurePermissions`
- `getFullStatus` with reCAPTCHA configured + real Site (end-to-end dashboard)

**Test results:** 257/257 Apex tests passed (100%). Org-wide coverage: 64%.

### v0.7.0 (2026-02-10) - v1 MVP: Hide reCAPTCHA for AppExchange Release
Hides all reCAPTCHA admin UI surfaces for the v1 AppExchange submission. reCAPTCHA adds onboarding friction (customers must get Google API keys), introduces an external HTTP dependency (complicates security review), and increases support burden. The feature is well-built but not essential for v1. All code remains intact and conditional — `Enable_Captcha__c` defaults to false and all frontend/backend logic is gated on it.

**Changes:**
- **Setup Wizard** (`setupWizard.js/html`): Reduced from 6 steps to 5 — reCAPTCHA step commented out, Complete step renumbered from 6 to 5. reCAPTCHA status messages hidden on Complete step.
- **Form Editor** (`formDetail.js/html`): "Enable CAPTCHA" checkbox hidden via `showCaptchaToggle` getter (returns `false`)
- **Setup Status Dashboard** (`setupStatus.js/html`): reCAPTCHA panel hidden via `showRecaptchaPanel` getter (returns `false`). Dashboard now shows 3 panels: Site, Permissions, URL.
- **Remote Site Setting** (`Google_reCAPTCHA.remoteSite-meta.xml`): Deactivated (`isActive=false`)

**Not modified** (all remain intact):
- `CaseFormController.cls` — captcha logic conditional on `Enable_Captcha__c`
- `WebToCaseRestAPI.cls` — API gates captcha config on the same flag
- `CaseFormPage.page` — VF rendering conditional on `captchaEnabled`
- `caseFormScript.js` / `caseFormWidget.js` — JS conditional on `enableCaptcha`
- `CaseFormControllerTest.cls` — all captcha tests pass (use mocks + explicit `Enable_Captcha__c = true`)
- `reCAPTCHA_Settings__c` and `Form__c.Enable_Captcha__c` — metadata stays in package

**Re-enabling for v2** — 4 toggles in 4 files, each marked with `v1 MVP` / `v2` comments:
1. `setupWizard.js` — Uncomment reCAPTCHA step, renumber back to 6 steps
2. `formDetail.js` — `showCaptchaToggle` returns `true`
3. `setupStatus.js` — `showRecaptchaPanel` returns `true`
4. `Google_reCAPTCHA.remoteSite-meta.xml` — `isActive` back to `true`

**Test results:** 227/227 Apex tests passed (100%). Playwright verified: 5 wizard steps, no CAPTCHA toggle in form editor, no reCAPTCHA panel in dashboard, form submission works without captcha (Case 00001114 created).

### v0.6.3 (2026-02-10) - CSS Bug Fixes, Nonce Retry, iframe Embed Support
- **6 CSS bug fixes in `caseFormWidget.js`**:
  1. Added `box-sizing: border-box` to inputs and submit button (prevents overflow with padding)
  2. Focus ring now respects `--wtc-primary-color` (was hardcoded Salesforce blue)
  3. Case number color uses `--wtc-success-color` (was hardcoded green)
  4. Disabled button uses `opacity: 0.6` instead of hardcoded gray (respects custom `--wtc-submit-background`)
  5. Removed self-referencing CSS variable declarations from `:host` (dead code per CSS spec)
  6. Error focus ring respects `--wtc-error-color` (was hardcoded red)
- **Added explicit fallbacks** to all bare `var(--wtc-*)` references throughout widget CSS
- **Transparent nonce retry**: On expired nonce errors, widget auto-fetches fresh config and resubmits once (no user action needed)
- **iframe embed support**: Changed Site clickjack protection from `SameOriginOnly` to `AllowAllFraming` to allow iframe embedding on external domains
- **CORS headers before errors**: Moved CORS header setting before error responses in all REST API endpoints so browsers can read error messages
- **Nonce service fix**: Fixed Platform Cache API to use partition-qualified calls; reduced nonce key from 256-bit to 128-bit to fit 50-char cache key limit
- **Snippet ID collisions fix**: Custom HTML tab in Admin UI now uses form-scoped IDs (`{formId}-file`, `{formId}-error`) instead of generic IDs
- **New metadata**:
  - `WebToCase.cachePartition` — Platform Cache partition for nonces
  - `dietrich_ai.corsWhitelistOrigin` / `dietrich_ai_bare.corsWhitelistOrigin` — CORS whitelist for dietrich.ai
  - `dietrich_ai.cspTrustedSite` — CSP trusted site for iframe embedding
  - `Support.site` — Salesforce Site metadata with `AllowAllFraming`

### v0.6.2 (2026-02-10) - Configuration Status Dashboard: Hide When Unconfigured + Auto-Refresh
- **setupStatus hidden when unconfigured**: Dashboard renders nothing when the org has no configuration, eliminating the redundant "Setup Not Complete" message
- **Auto-refresh via LMS**: When the Setup Wizard completes (Step 6), `setupStatus` automatically refreshes and appears without a page reload
- **New Lightning Message Channel**: `SetupStatusRefresh` for sibling component communication between `setupWizard` and `setupStatus`
- **Immediate card display**: Card shows loading spinner immediately on page load (no 2-second lag on configured orgs)

### v0.6.1 (2026-02-10) - Configuration Status Dashboard + Setup Wizard UI Fix
- **New LWC: `setupStatus`** - Configuration Status Dashboard showing real-time setup health
  - Displays Site configuration, Guest User permissions, reCAPTCHA status, and public form URL
  - Embedded in the Setup Wizard Lightning page alongside the wizard
  - Uses `SetupWizardController.getFullStatus()` for live status checks
  - Copy-to-clipboard for public form URL
  - Collapsible permission details section
- **Setup Wizard progress indicator**: Reverted from `type="path"` (chevron/arrow) to `type="base"` (standard dot stepper)

### v0.6.0 (2026-02-10) - Custom HTML Connect Mode + Extended CSS Variables
- **Connect mode** (`WebToCaseForm.connect()`): Bind submission logic to user's own HTML form — no Shadow DOM, full design control
  - Validates against form config using `aria-invalid` attributes
  - Collects only config-defined fields by `name` attribute
  - Supports file upload, CAPTCHA, chunked uploads, polling — all existing features
  - `destroy()` method for clean SPA re-initialization
  - Init-time console warnings for missing required field inputs
- **Extended CSS variables**: Expanded from 8 to 28 variables covering container, title, description, labels, inputs, field gap, submit button, success, and error styling
- **SubmissionMixin**: Internal refactor extracting shared submission-pipeline methods from FormWidget — no behavior change, enables code reuse by ConnectedForm
- **Admin UI: Embed Code section redesigned**:
  - SLDS scoped tabs (Widget / Custom HTML / iframe) replacing sequential layout
  - "Generate Embed Code" button — domains must be confirmed before snippets appear
  - Custom HTML tab generates HTML, CSS, and JS snippets from the form's actual fields
  - All tabs have Copy buttons for each snippet
- **Updated files**: `caseFormWidget.js` (CSS variables, SubmissionMixin, ConnectedForm, `connect()`), `formDetail.js/html/css` (snippets, handlers, scoped tabs)
- No backend (Apex) changes — connect mode uses the same REST endpoints

### v0.5.2 (2026-02-09) - Default Case Values for Form Admin
- **Default Case Values**: Admins can configure hidden Case field defaults per form (e.g., Priority=High, Type=Problem)
- **JSON storage**: Defaults stored as JSON on `Form__c.Default_Case_Values__c` (LongTextArea)
- **Allowlisted fields**: Priority, Status, Origin, Type, Reason — enforced server-side via `CaseDefaultFieldConfig`
- **Config-time validation**: `FormAdminController.saveForm()` validates JSON structure, allowlist, and non-blank string values
- **Submit-time application**: `CaseFormController.submitForm()` applies defaults between hardcoded fallbacks and user fields
- **DML retry resilience**: If invalid picklist values cause DML failure, system retries with a fresh Case (no defaults), logs error
- **Admin UI**: New "Default Case Values" accordion section in Form Detail with picklist-aware field/value selectors
- **New Apex class**: `CaseDefaultFieldConfig` — shared allowlist constant used by both controllers
- **New field**: `Form__c.Default_Case_Values__c` — LongTextArea(32768) for JSON defaults
- **New method**: `FormAdminController.getCaseFieldsForDefaults()` — returns field metadata with active picklist values
- **Updated permission set**: `Web_to_Case_Admin` — added read/edit for `Default_Case_Values__c`
- **Test coverage**: 12 new test methods (7 in FormAdminControllerTest, 5 in CaseFormControllerTest)

### v0.5.1 (2026-02-07) - 4MB Document Upload Limit
- **Increased document upload limit** from 2MB to 4MB using async Queueable assembly
- **New Apex class**: `FileAssemblyQueueable` - Assembles file chunks asynchronously using 12MB Queueable heap
  - Files <= 2MB (3 chunks): Assembled synchronously in CaseFormController (6MB heap)
  - Files 2-4MB (4+ chunks): Assembled asynchronously via Queueable (12MB heap)
- **Updated frontends**: caseFormScript.js (VF Remoting) and caseFormWidget.js (REST API) both enforce 4MB limit
- **Updated backend**: CaseFormController and WebToCaseRestAPI enforce 4MB hard cap server-side
- **Updated Admin UI**: Form Manager help text now reads "Documents: up to 4MB"
- **Chunk pattern**: `__chunk__{uploadKey}__{chunkIndex}__{totalChunks}__{fileName}` (750KB chunks)

### v0.5.0 (2026-02-03) - Phase 4: Embeddable Widget
- **Embeddable widget** for external websites with Shadow DOM isolation
- **Two embed modes**: Inline widget (recommended) and iframe embed
- **REST API** for cross-origin form operations (`/webtocase/v1/*`)
- **Security features**:
  - Origin validation with per-form domain allowlist
  - One-time nonces (15-min TTL) prevent replay attacks
  - Rate limiting (100 submissions/hour per origin)
  - Server-side field allowlist enforcement
- **CSS variable theming** for widget customization
- **postMessage API** for iframe height auto-resize
- **New Apex classes**:
  - `WebToCaseRestAPI` - REST endpoints with CORS support
  - `WebToCaseNonceService` - Nonce generation/validation
  - `WebToCaseRateLimiter` - Rate limiting logic
- **New static resource**: `caseFormWidget.js` - Embeddable widget script
- **New custom object**: `Rate_Limit_Counter__c` for rate limit tracking
- **New field**: `Form__c.Allowed_Domains__c` - Domain allowlist
- **Admin UI**: Embed Code section with code snippets and copy buttons
- **Test coverage**: WebToCaseRestAPITest with nonce, rate limit, and origin validation tests

### v0.4.8 (2026-02-02) - reCAPTCHA Type Change UX Fix
- **Fixed:** Users can now change reCAPTCHA type (v2 Checkbox, v2 Invisible, v3 Score) without re-entering the secret key
- Previously, the Setup Wizard required both Site Key and Secret Key to save any changes
- Now, when reCAPTCHA is already configured, users can change just the type and click Save
- Backend already supported partial updates (null values preserve existing) - this fix updates frontend validation to match
- First-time setup still requires both keys (unchanged behavior)

### v0.4.7 (2026-02-02) - Image Compression & Fixed File Limits
- **Image compression**: Images up to 25MB are automatically compressed to ~0.7MB before upload
  - Uses browser-image-compression library for client-side compression
  - Converts HEIC/PNG/WebP/BMP to JPEG for optimal size
  - Shows "Optimizing..." progress during compression
  - Compression target (0.7MB) ensures single-request upload without chunking
- **Fixed file limits**: Removed user-configurable "Max File Size" setting
  - Images: Up to 25MB (auto-compressed)
  - Documents (PDF, Word, etc.): Up to 4MB
  - Videos: Not supported (users prompted to email separately)
- **Simplified UX**: "Enable File Upload" checkbox now shows help text with limits
  - "Images: up to 25MB (auto-compressed) | Documents: up to 4MB"
- **New static resource**: `imageCompression.js` - browser-image-compression library (v2.0.2)
- **Removed**: "Max Document Size (MB)" input field from Form Manager

### v0.4.6 (2026-02-02) - Chunked File Upload Fix
- **Fixed:** Files larger than ~1.5MB could not be uploaded due to Salesforce Visualforce Remoting payload limits
- **Solution:** Implemented chunked file uploads for large files
  - Files ≤750KB: Uploaded in single request (as before)
  - Files >750KB: Automatically split into 750KB chunks and uploaded sequentially
  - Chunks are stored temporarily as ContentVersions, then assembled into final file
  - Chunk files are automatically cleaned up after assembly
- **New Apex methods:**
  - `uploadFileChunk(caseId, fileName, chunkData, chunkIndex, totalChunks, uploadKey)` - Handles chunk uploads
  - `getChunkSize()` - Returns chunk size for JavaScript reference
- **Updated JavaScript:** Added chunking logic, progress indicator during multi-chunk uploads
- **Test coverage:** 6 new unit tests for chunked upload scenarios
- **Note:** The `Max_File_Size_MB__c` setting now actually works for files up to the configured limit (previously limited to ~2MB)

### v0.4.5 (2026-01-29) - URL Display Feature
- **Site dropdown** added to Form Detail editor (new/edit form views)
  - Select per-form Site override or use org-wide default
  - Sites loaded from active Salesforce Sites in the org
- **Public URL display** with copy button in Form Detail view
  - Shows computed public URL based on selected Site
  - Warning message when no default Site is configured
- **"Copy URL" row action** added to Form Manager list view
  - Copies public form URL to clipboard with one click
  - Toast feedback on success/failure
- **Default Site configuration** saved during Setup Wizard (Step 2 → Step 3)
  - Stores both Site ID and resolved base URL in `reCAPTCHA_Settings__c`
- **"View Live" action** now uses correct public Site URL (not internal Salesforce URL)
- **New custom fields:**
  - `reCAPTCHA_Settings__c.Default_Site_Id__c` - Default Site ID for org
  - `reCAPTCHA_Settings__c.Default_Site_Base_Url__c` - Cached base URL
  - `Form__c.Site_Id__c` - Per-form Site override
- **URL encoding** for form names with special characters
- 143 Apex tests passing

### v0.4.4 (2026-01-29) - UX Improvements
- **Setup Wizard Complete step**: Consolidated from 4 boxes to 2 boxes for cleaner UX
  - Box 1: "Test Your Setup" - combines Sample Form, Test Form, and Public URL sections
  - Box 2: "What's Next" - links to Form Manager
  - Test Form section now only appears after sample form is created (prevents confusing "Form Not Available" errors)
  - Sample Form marked as "(Optional)" for clarity
- **Form Manager**: Added "Created" date column (shows when each form was created)
- **Form Manager**: Added column sorting - click any column header to sort ascending/descending
- **Form Editor**: Fixed dropdown overflow issue where "Maps to Case Field" dropdown was cut off at bottom of screen
- **Bug fix**: Fixed "SObject row was retrieved via SOQL without querying the requested field: Form__c.CreatedDate" error

### v0.4.3 (2026-01-29) - Setup Wizard Path Component Fix
- **Fixed:** Replaced custom CSS chevron path with standard `lightning-progress-indicator` component
- Eliminates persistent white gap issues between chevron steps
- Native Salesforce component handles complete/current/incomplete styling automatically
- Simplified codebase: removed ~245 lines of custom CSS and ~50 lines of JS
- Click navigation on steps still works via `data-step` attribute

### v0.4.2 (2026-01-29) - reCAPTCHA v3 Support & UX Improvements
- **reCAPTCHA v3 Score-based** support added alongside v2 Checkbox and v2 Invisible
- **reCAPTCHA Type selector** in Setup Wizard with clear descriptions for each type
- **Simplified Score Threshold UX** - removed confusing technical input, uses sensible default (0.3)
- Admins can still adjust threshold via Setup → Custom Metadata Types if needed
- Updated `reCAPTCHA_Settings__c` with `Captcha_Type__c` and `Score_Threshold__c` fields
- Server-side v3 score verification with configurable threshold
- Client-side v3 integration with invisible badge

### v0.4.1 (2026-01-29) - Setup Wizard reCAPTCHA Configuration
- **Added Step 5: reCAPTCHA** to Setup Wizard (wizard now has 6 steps)
- Admin-friendly UI for configuring reCAPTCHA API keys without Anonymous Apex
- Partial updates supported (update Site Key or Secret Key independently)
- Input validation (max 255 chars, whitespace trimming)
- "Skip for Now" option for users who don't need CAPTCHA
- Warning on Complete step if reCAPTCHA was skipped
- 11 new unit tests for reCAPTCHA settings (41 total in SetupWizardControllerTest)
- 114 total tests passing across all controllers

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
- 5-step post-install setup wizard (expanded to 6 steps in v0.4.1, reduced back to 5 in v0.7.0)
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

## Manual Testing Still Needed

See the **🧪 MANUAL TESTING REQUIRED** section at the top of this README for the current testing checklist.

---

## Next Session Starting Point

**Status:** Phases 0-4 complete. v0.7.2 deployed. All classes above 75% coverage. Ready for AppExchange submission (namespace prefix + managed package) or Phase 5.

**Recent changes (v0.7.2):**
- Fixed Setup Wizard "Configure Permissions" error for `Error_Log__c.Timestamp__c`
- Removed required field from `REQUIRED_FIELD_READ` map (FLS auto-granted by Salesforce)

**Previous (v0.7.1):**
- `WebToCaseNonceService` test coverage: 51% → 81% (14 new tests)
- `SetupWizardController` test coverage: 50% → 86% (12 new tests)
- 257/257 tests passing, 64% org-wide coverage
- All AppExchange test coverage requirements met

**Previous (v0.7.0):**
- reCAPTCHA hidden from all admin UI for v1 MVP AppExchange release
- Setup Wizard: 5 steps (was 6) — reCAPTCHA step removed, Complete renumbered
- 4 files to toggle for v2 re-enablement (each marked with `v1 MVP` comments)

**Previous (v0.6.3):**
- 6 CSS bug fixes in widget (box-sizing, focus ring colors, disabled opacity, `:host` dead code cleanup)
- Transparent nonce retry on expired nonces (auto-fetches fresh config and resubmits)
- iframe embed enabled (AllowAllFraming on Site, CSP trusted site for dietrich.ai)
- CORS headers sent before error responses in REST API

**File size limits (fixed):**
| File Type | Limit | Behavior |
|-----------|-------|----------|
| Images (JPEG, PNG, HEIC, WebP, BMP) | 25MB | Auto-compressed to ~0.7MB |
| Documents (PDF, Word, etc.) | 4MB | Hard limit (async assembly via Queueable) |
| Videos | N/A | Not supported |

**Key architecture notes:**
- Forms are **org-wide** (not tied to specific Sites)
- Sites are just public entry points - any configured Site can serve any form
- Users can run the Setup Wizard multiple times for different Sites
- Image compression happens client-side using browser-image-compression library

**Dev org:** `tilman.dietrich@gmail.com.dev` (alias: `devorg`)

**GitHub:** https://github.com/tilman-d/salesforce-webtocase

**Quick start for next session:**
```bash
cd /root/caseformpage
sf org login web --alias devorg  # if needed
sf project deploy start --target-org devorg
```

---

### Re-enabling reCAPTCHA for v2

All reCAPTCHA code is intact and conditional. To re-enable for v2, change 4 toggles in 4 files (each marked with `v1 MVP` / `v2` comments):

| File | Change |
|------|--------|
| `setupWizard.js` | Uncomment reCAPTCHA step in `STEPS`, renumber Complete back to `'6'`, restore step logic |
| `formDetail.js` | Change `showCaptchaToggle` to return `true` |
| `setupStatus.js` | Change `showRecaptchaPanel` to return `true` |
| `Google_reCAPTCHA.remoteSite-meta.xml` | Change `<isActive>false</isActive>` to `true` |

Search for `v1 MVP` across the codebase to find all change points.

### Phase 5 Implementation Ideas

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

---

## AppExchange Package Metadata

When creating the managed/unlocked package for AppExchange, include the following metadata components:

### Custom Objects (4)
| Component | API Name | Description |
|-----------|----------|-------------|
| Custom Object | `Form__c` | Form configuration |
| Custom Object | `Form_Field__c` | Form field definitions |
| Custom Object | `Error_Log__c` | Error logging |
| Custom Object | `Rate_Limit_Counter__c` | Rate limit tracking (Phase 4) |

### Custom Settings (1)
| Component | API Name | Description |
|-----------|----------|-------------|
| Custom Setting (Hierarchy) | `reCAPTCHA_Settings__c` | reCAPTCHA API keys and settings (Protected) |

### Custom Fields - Form__c (11)
| Field | API Name |
|-------|----------|
| Form Name | `Form_Name__c` |
| Title | `Title__c` |
| Description | `Description__c` |
| Success Message | `Success_Message__c` |
| Active | `Active__c` |
| Enable File Upload | `Enable_File_Upload__c` |
| Max File Size MB | `Max_File_Size_MB__c` |
| Enable Captcha | `Enable_Captcha__c` |
| Site Id | `Site_Id__c` |
| Allowed Domains | `Allowed_Domains__c` (Phase 4) |
| Default Case Values | `Default_Case_Values__c` - JSON defaults for hidden Case fields |

### Custom Fields - Form_Field__c (6)
| Field | API Name |
|-------|----------|
| Form (Master-Detail) | `Form__c` |
| Field Label | `Field_Label__c` |
| Field Type | `Field_Type__c` |
| Case Field | `Case_Field__c` |
| Required | `Required__c` |
| Sort Order | `Sort_Order__c` |

### Custom Fields - Error_Log__c (4)
| Field | API Name |
|-------|----------|
| Error Message | `Error_Message__c` |
| Stack Trace | `Stack_Trace__c` |
| Form Id | `Form_Id__c` |
| Timestamp | `Timestamp__c` |

### Custom Fields - reCAPTCHA_Settings__c (6)
| Field | API Name |
|-------|----------|
| Site Key | `Site_Key__c` |
| Secret Key | `Secret_Key__c` |
| Captcha Type | `Captcha_Type__c` |
| Score Threshold | `Score_Threshold__c` |
| Default Site Id | `Default_Site_Id__c` |
| Default Site Base Url | `Default_Site_Base_Url__c` |

### Custom Fields - Rate_Limit_Counter__c (4) - Phase 4
| Field | API Name |
|-------|----------|
| Origin Key | `Origin_Key__c` |
| Origin Domain | `Origin_Domain__c` |
| Count | `Count__c` |
| Hour Bucket | `Hour_Bucket__c` |

### Apex Classes (15)
| Class | Description |
|-------|-------------|
| `CaseDefaultFieldConfig` | Shared allowlist of Case fields for default values |
| `CaseFormController` | Public form controller |
| `CaseFormControllerTest` | Test class |
| `ErrorLogger` | Error logging utility |
| `ErrorLoggerTest` | Test class |
| `FileAssemblyQueueable` | Async file chunk assembly for files >2MB (up to 4MB) |
| `FileAssemblyQueueableTest` | Test class |
| `FormAdminController` | Form Manager admin controller |
| `FormAdminControllerTest` | Test class |
| `SetupWizardController` | Setup Wizard controller |
| `SetupWizardControllerTest` | Test class |
| `WebToCaseRestAPI` | REST API for embed widget (Phase 4) |
| `WebToCaseNonceService` | Nonce management for security (Phase 4) |
| `WebToCaseRateLimiter` | Rate limiting logic (Phase 4) |
| `WebToCaseRestAPITest` | Test class (Phase 4) |

### Lightning Message Channels (1)
| Channel | API Name | Description |
|---------|----------|-------------|
| Setup Status Refresh | `SetupStatusRefresh` | Notifies setupStatus to refresh after wizard completes |

### Lightning Web Components (4)
| Component | Description |
|-----------|-------------|
| `formAdminApp` | Form Manager main container |
| `formDetail` | Form editor with field management |
| `setupStatus` | Configuration Status Dashboard |
| `setupWizard` | Post-install setup wizard |

### Visualforce Pages (1)
| Page | Description |
|------|-------------|
| `CaseFormPage` | Public form page |

### Static Resources (4)
| Resource | Description |
|----------|-------------|
| `caseFormStyles` | Form CSS styling |
| `caseFormScript` | Form JavaScript (validation, compression, submission) |
| `imageCompression` | browser-image-compression library for client-side image optimization |
| `caseFormWidget` | Embeddable widget script for external websites (Phase 4) |

### Lightning App (1)
| App | API Name |
|-----|----------|
| Web-to-Case Forms | `Web_to_Case_Forms` |

### Lightning Pages (FlexiPages) (2)
| Page | API Name |
|------|----------|
| Form Manager | `Form_Manager` |
| Setup Wizard | `Setup_Wizard` |

### Custom Tabs (2)
| Tab | API Name |
|-----|----------|
| Form Manager | `Form_Manager` |
| Setup Wizard | `Setup_Wizard` |

### Permission Sets (1)
| Permission Set | API Name |
|----------------|----------|
| Web-to-Case Admin | `Web_to_Case_Admin` |

### Remote Site Settings (1)
| Remote Site | URL | Description |
|-------------|-----|-------------|
| Google_reCAPTCHA | `https://www.google.com` | reCAPTCHA verification API (deactivated in v1 MVP) |

### Platform Cache Partitions (1)
| Partition | API Name | Description |
|-----------|----------|-------------|
| WebToCase | `WebToCase` | Stores one-time nonces for replay attack prevention (15-min TTL) |

### Org-Specific Metadata (Excluded from Package)

The following metadata types are org-specific and should NOT be included in the managed package. Customers configure their own via Salesforce Setup:

- **CORS Whitelist Origins** — customers add their own domains
- **CSP Trusted Sites** — customers add their own domains
- **Custom Sites** — customers create their own Site

These are excluded via `.forceignore`.

### Package.xml Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>Form__c</members>
        <members>Form_Field__c</members>
        <members>Error_Log__c</members>
        <members>Rate_Limit_Counter__c</members>
        <name>CustomObject</name>
    </types>
    <types>
        <members>reCAPTCHA_Settings__c</members>
        <name>CustomObject</name>
    </types>
    <types>
        <members>CaseDefaultFieldConfig</members>
        <members>CaseFormController</members>
        <members>CaseFormControllerTest</members>
        <members>ErrorLogger</members>
        <members>ErrorLoggerTest</members>
        <members>FileAssemblyQueueable</members>
        <members>FileAssemblyQueueableTest</members>
        <members>FormAdminController</members>
        <members>FormAdminControllerTest</members>
        <members>SetupWizardController</members>
        <members>SetupWizardControllerTest</members>
        <members>WebToCaseRestAPI</members>
        <members>WebToCaseNonceService</members>
        <members>WebToCaseRateLimiter</members>
        <members>WebToCaseRestAPITest</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>formAdminApp</members>
        <members>formDetail</members>
        <members>setupStatus</members>
        <members>setupWizard</members>
        <name>LightningComponentBundle</name>
    </types>
    <types>
        <members>CaseFormPage</members>
        <name>ApexPage</name>
    </types>
    <types>
        <members>caseFormStyles</members>
        <members>caseFormScript</members>
        <members>imageCompression</members>
        <members>caseFormWidget</members>
        <name>StaticResource</name>
    </types>
    <types>
        <members>Web_to_Case_Forms</members>
        <name>CustomApplication</name>
    </types>
    <types>
        <members>Form_Manager</members>
        <members>Setup_Wizard</members>
        <name>FlexiPage</name>
    </types>
    <types>
        <members>Form_Manager</members>
        <members>Setup_Wizard</members>
        <name>CustomTab</name>
    </types>
    <types>
        <members>Web_to_Case_Admin</members>
        <name>PermissionSet</name>
    </types>
    <types>
        <members>Google_reCAPTCHA</members>
        <name>RemoteSiteSetting</name>
    </types>
    <types>
        <members>SetupStatusRefresh</members>
        <name>LightningMessageChannel</name>
    </types>
    <types>
        <members>WebToCase</members>
        <name>PlatformCachePartition</name>
    </types>
    <!-- CORS, CSP, and Sites are org-specific — excluded from package -->
    <version>59.0</version>
</Package>
```

### Notes for Packaging

1. **Custom Setting**: `reCAPTCHA_Settings__c` is a Protected Hierarchy Custom Setting. The records themselves (API keys) are NOT included - users configure these post-install via Setup Wizard.

2. **Remote Site Setting**: Include `Google_reCAPTCHA` for reCAPTCHA verification callouts (deactivated in v1 MVP — included in package but inactive).

3. **Permission Set**: `Web_to_Case_Admin` grants access to all admin functionality. Assign to users who need to manage forms.

4. **Post-Install Configuration Required**:
   - Create/select a Salesforce Site
   - Configure Guest User permissions (via Setup Wizard)
   - Grant Apex class and VF page access to Guest User profile
   - (v2 only) Add reCAPTCHA API keys via Setup Wizard

5. **Test Coverage**: All Apex classes have >75% code coverage. 257 tests passing, 64% org-wide coverage.

6. **Platform Cache**: The `WebToCase` cache partition is required for nonce-based replay attack prevention. The org must have Platform Cache allocated (at least session cache).

7. **CORS, CSP & Sites**: Org-specific metadata (CORS origins, CSP trusted sites, Site config) has been removed from the project and excluded via `.forceignore`. Customers configure their own domains post-install.

8. **Site Metadata**: Customers using iframe embed mode need `AllowAllFraming` on their Site (documented in post-install Setup Wizard).
