# Web-to-Case with Attachments

A Salesforce app that lets you create public web forms that submit Cases with file attachments. Built for the AppExchange.

---

## 🧪 MANUAL TESTING REQUIRED: reCAPTCHA Issues

The following reCAPTCHA items need manual verification before release:

### reCAPTCHA v3 Testing
- [ ] Create reCAPTCHA v3 keys at Google Admin Console (select "v3")
- [ ] Configure v3 in Setup Wizard (select "v3 Score-based" type)
- [ ] Test form submission with v3 - verify invisible badge appears
- [ ] Verify low-score submissions are blocked (use VPN/incognito to simulate bot-like behavior)
- [ ] Test switching between v2 Checkbox, v2 Invisible, and v3 Score-based

---

## Quick Status

| | |
|---|---|
| **Version** | v0.5.0 |
| **Phases Complete** | 0-4 (MVP, Admin UI, Setup Wizard, reCAPTCHA, Embeddable Widget) |
| **Next Up** | Phase 5 (Multi-file upload, custom field types) |
| **Dev Org** | `devorg` (tilman.dietrich@gmail.com.dev) |
| **GitHub** | https://github.com/tilman-d/salesforce-webtocase |
| **Last Change** | Allow changing reCAPTCHA type without re-entering secret key |

---

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

**6-Step Wizard Flow:**
1. **Welcome** - Precondition checks (My Domain, admin permissions, Sites enabled)
2. **Select Site** - Choose from existing Sites or get instructions to create one
3. **Configure** - Auto-configure Guest User object/field permissions with security acknowledgment
4. **Verify** - Manual configuration instructions for Apex class and VF page access with validation
5. **reCAPTCHA** - Configure Google reCAPTCHA API keys (optional, can skip)
6. **Complete** - Simplified 2-box layout:
   - "Test Your Setup" box: Sample form creation (optional), Test Form button, Public URL with copy
   - "What's Next" box: Link to Form Manager

**Features:**
- Automatic detection of active Salesforce Sites
- One-click permission configuration for Guest User profile
- Support for both Enhanced Profile UI and Classic Profile UI instructions
- Validation to ensure all permissions are correctly configured
- **reCAPTCHA configuration UI** - Enter Site Key and Secret Key without Anonymous Apex
- Sample "Contact Support" form creation
- Dynamic public URL generation (works with Enhanced Domains)

### Apex Classes
- **SetupWizardController** - Site detection, permission configuration, validation, sample form creation, reCAPTCHA settings management
- **SetupWizardControllerTest** - Unit tests with coverage (41 tests)

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

## What's Built (Phase 4)

### Embeddable Widget for External Websites
Allows users to embed Web-to-Case forms on external websites using a `<script>` tag.

**Two Embed Modes:**

#### Mode 1: Inline Widget (Recommended)
- Uses Shadow DOM for CSS isolation
- Customizable via CSS variables
- Form rendered directly in the host page

#### Mode 2: iframe Embed
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
  - Allowed Domains textarea
  - Auto-generated embed code snippets
  - Copy buttons for code
  - reCAPTCHA domain warning

### CSS Variables for Styling

```css
#support-form {
  --wtc-primary-color: #0176d3;
  --wtc-font-family: system-ui, sans-serif;
  --wtc-border-radius: 4px;
  --wtc-input-border: 1px solid #c9c9c9;
  --wtc-input-background: #ffffff;
  --wtc-text-color: #181818;
  --wtc-error-color: #c23934;
  --wtc-success-color: #2e844a;
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
    // Note: File limits are fixed (Images: 25MB auto-compressed, Documents: 2MB)
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
├── objects/
│   ├── Form__c/                         # Form configuration
│   │   └── fields/
│   │       ├── Enable_Captcha__c        # Phase 3
│   │       ├── Site_Id__c               # URL Display Feature
│   │       └── Allowed_Domains__c       # Phase 4 - Embed allowlist
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
│   ├── CaseFormController.cls
│   ├── CaseFormControllerTest.cls
│   ├── ErrorLogger.cls
│   ├── ErrorLoggerTest.cls
│   ├── FormAdminController.cls          # Phase 1
│   ├── FormAdminControllerTest.cls      # Phase 1
│   ├── SetupWizardController.cls        # Phase 2
│   ├── SetupWizardControllerTest.cls    # Phase 2
│   ├── WebToCaseRestAPI.cls             # Phase 4 - REST endpoints
│   ├── WebToCaseNonceService.cls        # Phase 4 - Nonce management
│   ├── WebToCaseRateLimiter.cls         # Phase 4 - Rate limiting
│   └── WebToCaseRestAPITest.cls         # Phase 4 - Tests
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
│   ├── caseFormScript.js                # + compression, validation, postMessage
│   ├── caseFormWidget.js                # Phase 4 - Embeddable widget
│   └── imageCompression.js              # browser-image-compression library
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
  - Documents (PDF, Word, etc.): Up to 2MB
  - Videos: Not supported (users prompted to email separately)
- **Simplified UX**: "Enable File Upload" checkbox now shows help text with limits
  - "Images: up to 25MB (auto-compressed) | Documents: up to 2MB"
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
- 5-step post-install setup wizard (now 6 steps with reCAPTCHA config)
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

**Status:** Phases 0-4 complete. Ready for Phase 5 (multi-file upload, custom field types).

**Recent changes (v0.5.0):**
- Embeddable widget for external websites with Shadow DOM isolation
- REST API (`/webtocase/v1/*`) with CORS support
- Security: Origin validation, one-time nonces, rate limiting
- Admin UI: Embed Code section with code snippets and domain allowlist
- 175 Apex tests passing, 11 Playwright tests passing

**File size limits (fixed):**
| File Type | Limit | Behavior |
|-----------|-------|----------|
| Images (JPEG, PNG, HEIC, WebP, BMP) | 25MB | Auto-compressed to ~0.7MB |
| Documents (PDF, Word, etc.) | 2MB | Hard limit |
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

### Custom Fields - Form__c (10)
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

### Apex Classes (12)
| Class | Description |
|-------|-------------|
| `CaseFormController` | Public form controller |
| `CaseFormControllerTest` | Test class |
| `ErrorLogger` | Error logging utility |
| `ErrorLoggerTest` | Test class |
| `FormAdminController` | Form Manager admin controller |
| `FormAdminControllerTest` | Test class |
| `SetupWizardController` | Setup Wizard controller |
| `SetupWizardControllerTest` | Test class |
| `WebToCaseRestAPI` | REST API for embed widget (Phase 4) |
| `WebToCaseNonceService` | Nonce management for security (Phase 4) |
| `WebToCaseRateLimiter` | Rate limiting logic (Phase 4) |
| `WebToCaseRestAPITest` | Test class (Phase 4) |

### Lightning Web Components (3)
| Component | Description |
|-----------|-------------|
| `formAdminApp` | Form Manager main container |
| `formDetail` | Form editor with field management |
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
| Google_reCAPTCHA | `https://www.google.com` | reCAPTCHA verification API |

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
        <members>CaseFormController</members>
        <members>CaseFormControllerTest</members>
        <members>ErrorLogger</members>
        <members>ErrorLoggerTest</members>
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
    <version>59.0</version>
</Package>
```

### Notes for Packaging

1. **Custom Setting**: `reCAPTCHA_Settings__c` is a Protected Hierarchy Custom Setting. The records themselves (API keys) are NOT included - users configure these post-install via Setup Wizard.

2. **Remote Site Setting**: Include `Google_reCAPTCHA` for reCAPTCHA verification callouts.

3. **Permission Set**: `Web_to_Case_Admin` grants access to all admin functionality. Assign to users who need to manage forms.

4. **Post-Install Configuration Required**:
   - Create/select a Salesforce Site
   - Configure Guest User permissions (via Setup Wizard)
   - Add reCAPTCHA API keys (via Setup Wizard)
   - Grant Apex class and VF page access to Guest User profile

5. **Test Coverage**: All Apex classes have >75% code coverage with dedicated test classes.
