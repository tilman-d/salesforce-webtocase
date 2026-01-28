# Future Phases - Web-to-Case with Attachments

## Prerequisites

**Phase 0 and Phase 1 must be complete before starting these features.**

Verify:
- [ ] Phase 0: Core form submission works
- [ ] Phase 1: Admin UI works

---

## Phase 2: reCAPTCHA Integration

### Goal
Add spam protection using Google reCAPTCHA v2 (checkbox).

### Implementation

#### Data Model Additions

**Captcha_Settings__c (Protected Custom Setting - Hierarchy)**
```
Fields:
├── Site_Key__c (Text 255) - Google reCAPTCHA site key (public)
└── Secret_Key__c (Text 255) - Google reCAPTCHA secret key (protected)
```

**Form__c additions:**
- `Enable_Captcha__c` (Checkbox) - Enable reCAPTCHA for this form

#### Apex Changes

**CaptchaService.cls**
```apex
public class CaptchaService {

    private static final String VERIFY_URL = 'https://www.google.com/recaptcha/api/siteverify';

    public static Boolean verify(String token) {
        Captcha_Settings__c settings = Captcha_Settings__c.getOrgDefaults();
        if (String.isBlank(settings.Secret_Key__c)) {
            return true; // Captcha not configured, allow through
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(VERIFY_URL);
        req.setMethod('POST');
        req.setBody('secret=' + settings.Secret_Key__c + '&response=' + token);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (Boolean) result.get('success');
        }

        return false;
    }

    @AuraEnabled(cacheable=true)
    public static String getSiteKey() {
        Captcha_Settings__c settings = Captcha_Settings__c.getOrgDefaults();
        return settings.Site_Key__c;
    }
}
```

**CaseFormController.cls changes:**
```apex
@RemoteAction
global static Map<String, Object> submitForm(String formId, Map<String, String> fieldValues,
                                              String fileName, String fileContent, String captchaToken) {
    // Verify captcha first
    Form__c form = [SELECT Enable_Captcha__c FROM Form__c WHERE Id = :formId];
    if (form.Enable_Captcha__c && !CaptchaService.verify(captchaToken)) {
        return new Map<String, Object>{
            'success' => false,
            'error' => 'reCAPTCHA verification failed. Please try again.'
        };
    }

    // ... rest of existing code
}
```

#### Visualforce Changes

Add to CaseFormPage.page:
```html
<apex:outputPanel rendered="{!form.Enable_Captcha__c}">
    <div class="form-field">
        <div id="recaptcha"></div>
    </div>
</apex:outputPanel>

<script src="https://www.google.com/recaptcha/api.js?onload=onRecaptchaLoad&render=explicit" async defer></script>
<script>
    var captchaSiteKey = '{!JSENCODE(captchaSiteKey)}';
    var captchaWidgetId;

    function onRecaptchaLoad() {
        captchaWidgetId = grecaptcha.render('recaptcha', {
            sitekey: captchaSiteKey
        });
    }

    // In submit function, get token:
    var captchaToken = grecaptcha.getResponse(captchaWidgetId);
</script>
```

#### Remote Site Setting
Create Remote Site Setting for `https://www.google.com`

#### Customer Setup Documentation
1. Go to google.com/recaptcha and register your site
2. Get Site Key and Secret Key
3. In Salesforce Setup → Custom Settings → Captcha Settings → Manage
4. Enter Site Key and Secret Key
5. Enable captcha on individual forms

### Files to Create
```
force-app/main/default/
├── classes/
│   ├── CaptchaService.cls
│   ├── CaptchaService.cls-meta.xml
│   ├── CaptchaServiceTest.cls
│   └── CaptchaServiceTest.cls-meta.xml
├── customSettings/
│   └── Captcha_Settings__c.customSetting-meta.xml
└── remoteSiteSettings/
    └── Google_reCAPTCHA.remoteSiteSetting-meta.xml
```

---

## Phase 3: Debug Dashboard

### Goal
Provide visibility into errors and system health for admins.

### Implementation

#### Data Model (from Phase 0)
Error_Log__c already exists with:
- Timestamp__c
- Error_Message__c
- Stack_Trace__c
- Form_Id__c

Add:
- `Resolved__c` (Checkbox) - Mark as resolved
- `Error_Type__c` (Picklist) - Apex, Validation, File, Captcha, Other

#### Debug_Settings__c (Custom Setting)
```
Fields:
├── Debug_Mode__c (Checkbox) - Enable verbose error messages
└── Log_Retention_Days__c (Number) - Days to keep logs (default: 30)
```

#### LWC Component: debugDashboard

**Features:**
- List Error_Log__c records in datatable
- Filter by: Form, Error Type, Date Range, Resolved status
- Mark errors as resolved (single or bulk)
- Auto-refresh toggle
- Clear old logs button
- Health check display (optional)

**debugDashboard.js**
```javascript
import { LightningElement, wire, track } from 'lwc';
import getErrorLogs from '@salesforce/apex/DebugController.getErrorLogs';
import markResolved from '@salesforce/apex/DebugController.markResolved';
import clearOldLogs from '@salesforce/apex/DebugController.clearOldLogs';

export default class DebugDashboard extends LightningElement {
    @track logs = [];
    @track filterFormId = '';
    @track filterErrorType = '';
    @track filterResolved = false;
    @track dateFrom = null;
    @track dateTo = null;

    columns = [
        { label: 'Time', fieldName: 'Timestamp__c', type: 'date',
          typeAttributes: { hour: '2-digit', minute: '2-digit' }},
        { label: 'Error Type', fieldName: 'Error_Type__c' },
        { label: 'Message', fieldName: 'Error_Message__c', wrapText: true },
        { label: 'Form', fieldName: 'Form_Id__c' },
        { label: 'Resolved', fieldName: 'Resolved__c', type: 'boolean' },
        { type: 'action', typeAttributes: { rowActions: [
            { label: 'View Details', name: 'view' },
            { label: 'Mark Resolved', name: 'resolve' }
        ]}}
    ];

    @wire(getErrorLogs, {
        formId: '$filterFormId',
        errorType: '$filterErrorType',
        showResolved: '$filterResolved',
        dateFrom: '$dateFrom',
        dateTo: '$dateTo'
    })
    wiredLogs({ data, error }) {
        if (data) this.logs = data;
    }

    async handleMarkResolved(logIds) {
        await markResolved({ logIds });
        // Refresh
    }

    async handleClearOldLogs() {
        const count = await clearOldLogs();
        // Show toast: "Cleared X old log entries"
    }
}
```

**DebugController.cls**
```apex
public with sharing class DebugController {

    @AuraEnabled(cacheable=true)
    public static List<Error_Log__c> getErrorLogs(String formId, String errorType,
                                                   Boolean showResolved, Date dateFrom, Date dateTo) {
        String query = 'SELECT Id, Timestamp__c, Error_Type__c, Error_Message__c, ' +
                       'Stack_Trace__c, Form_Id__c, Resolved__c ' +
                       'FROM Error_Log__c WHERE Id != null ';

        if (String.isNotBlank(formId)) {
            query += ' AND Form_Id__c = :formId ';
        }
        if (String.isNotBlank(errorType)) {
            query += ' AND Error_Type__c = :errorType ';
        }
        if (!showResolved) {
            query += ' AND Resolved__c = false ';
        }
        if (dateFrom != null) {
            query += ' AND Timestamp__c >= :dateFrom ';
        }
        if (dateTo != null) {
            query += ' AND Timestamp__c <= :dateTo ';
        }

        query += ' ORDER BY Timestamp__c DESC LIMIT 200';

        return Database.query(query);
    }

    @AuraEnabled
    public static void markResolved(List<Id> logIds) {
        List<Error_Log__c> logs = new List<Error_Log__c>();
        for (Id logId : logIds) {
            logs.add(new Error_Log__c(Id = logId, Resolved__c = true));
        }
        update logs;
    }

    @AuraEnabled
    public static Integer clearOldLogs() {
        Debug_Settings__c settings = Debug_Settings__c.getOrgDefaults();
        Integer retentionDays = settings.Log_Retention_Days__c != null
            ? (Integer) settings.Log_Retention_Days__c : 30;

        Date cutoff = Date.today().addDays(-retentionDays);
        List<Error_Log__c> oldLogs = [
            SELECT Id FROM Error_Log__c
            WHERE Timestamp__c < :cutoff
            LIMIT 10000
        ];

        delete oldLogs;
        return oldLogs.size();
    }
}
```

### Files to Create
```
force-app/main/default/
├── classes/
│   ├── DebugController.cls
│   ├── DebugController.cls-meta.xml
│   ├── DebugControllerTest.cls
│   └── DebugControllerTest.cls-meta.xml
├── lwc/
│   └── debugDashboard/
│       ├── debugDashboard.html
│       ├── debugDashboard.js
│       ├── debugDashboard.js-meta.xml
│       └── debugDashboard.css
└── customSettings/
    └── Debug_Settings__c.customSetting-meta.xml
```

---

## Phase 4: Embed Support (JavaScript Widget)

### Goal
Allow customers to embed forms on their external websites via iframe or JavaScript snippet.

### Implementation

#### Approach 1: iFrame Embed (Simplest)
The existing Visualforce page already works in an iframe. Just generate the embed code.

**formBuilderHome.js - Add "Get Embed Code" action:**
```javascript
getEmbedCode(formId, formName) {
    const siteUrl = 'https://[CUSTOMER_DOMAIN].my.salesforce-sites.com';
    const formUrl = `${siteUrl}/CaseFormPage?name=${formName}`;

    const iframeCode = `<iframe
    src="${formUrl}"
    width="100%"
    height="600"
    frameborder="0"
    style="border: none;">
</iframe>`;

    return iframeCode;
}
```

**EmbedCodeModal LWC:**
- Display textarea with embed code
- Copy to clipboard button
- Instructions for adding to website

#### Approach 2: JavaScript Widget (More Advanced)
Create a JS file that loads the form dynamically.

**formWidget.js (Static Resource)**
```javascript
(function() {
    var config = window.CaseFormWidget || {};
    var formName = config.formName;
    var containerId = config.containerId || 'case-form-widget';
    var siteUrl = config.siteUrl;

    if (!formName || !siteUrl) {
        console.error('CaseFormWidget: formName and siteUrl are required');
        return;
    }

    var container = document.getElementById(containerId);
    if (!container) {
        console.error('CaseFormWidget: Container element not found');
        return;
    }

    var iframe = document.createElement('iframe');
    iframe.src = siteUrl + '/CaseFormPage?name=' + encodeURIComponent(formName);
    iframe.width = config.width || '100%';
    iframe.height = config.height || '600';
    iframe.frameBorder = '0';
    iframe.style.border = 'none';

    container.appendChild(iframe);
})();
```

**Customer Usage:**
```html
<div id="case-form-widget"></div>
<script>
    window.CaseFormWidget = {
        formName: 'support',
        siteUrl: 'https://acme.my.salesforce-sites.com',
        width: '100%',
        height: '600'
    };
</script>
<script src="https://acme.my.salesforce-sites.com/resource/formWidget"></script>
```

#### Salesforce Site Settings
Ensure X-Frame-Options allows embedding:
- Setup → Sites → [Your Site] → Edit
- Clickjack Protection Level: "Allow framing by any page"

### Files to Create
```
force-app/main/default/
├── lwc/
│   └── embedCodeModal/
│       ├── embedCodeModal.html
│       ├── embedCodeModal.js
│       └── embedCodeModal.js-meta.xml
└── staticresources/
    ├── formWidget.js
    └── formWidget.resource-meta.xml
```

---

## Phase 5: Advanced Features (Post-Launch)

### 5.1 Multi-File Upload
Current: Single file upload
Future: Multiple files with drag-drop zone

### 5.2 Conditional Fields
Show/hide fields based on other field values.

### 5.3 Custom Styling
Allow customers to customize colors, fonts via Form__c fields or CSS override.

### 5.4 Form Analytics
Track submissions, conversion rates, popular forms.

### 5.5 Email Notifications
Custom notification emails to support team on submission.

### 5.6 Webhooks
Call external URLs on form submission.

### 5.7 Field Validation Rules
Regex patterns, min/max length, custom error messages.

### 5.8 Form Templates
Pre-built form templates (Support, Feedback, Contact Us).

### 5.9 Multi-Language Support
Translations for form labels and messages.

### 5.10 GDPR/Privacy Features
Consent checkboxes, data retention policies.

---

## AppExchange Preparation

### Security Review Checklist
- [ ] No SOQL injection (use bind variables)
- [ ] CRUD/FLS enforcement in all Apex
- [ ] No hardcoded credentials
- [ ] Input sanitization
- [ ] File type validation (server-side)
- [ ] Proper sharing model (with/without sharing)
- [ ] No sensitive data in debug logs
- [ ] Secure HTTP callouts (HTTPS only)
- [ ] Test coverage 75%+ (aim for 85%+)

### Package Components
1. Custom Objects (Form__c, Form_Field__c, Error_Log__c)
2. Custom Settings (Captcha_Settings__c, Debug_Settings__c)
3. Apex Classes (all controllers and services)
4. Visualforce Pages
5. Lightning Web Components
6. Static Resources (CSS, JS)
7. Permission Sets
8. Custom Tabs
9. Flexipages

### Pricing Strategy (Recommendation)
| Tier | Price | Limits |
|------|-------|--------|
| Starter | $19/org/mo | 1 form, 500 submissions/mo |
| Professional | $49/org/mo | 5 forms, 2500 submissions/mo |
| Business | $99/org/mo | Unlimited forms, 10K submissions/mo |

### Marketing Positioning
"Web-to-Case that actually works. File uploads included. Live in 5 minutes."

Target buyers:
- Service Cloud customers
- IT admins without developer resources
- Salesforce consultants implementing Service Cloud

---

## Timeline Summary

| Phase | Scope | Duration |
|-------|-------|----------|
| Phase 0 | MVP Core | 1 week |
| Phase 1 | Admin UI | 1-2 weeks |
| Phase 2 | reCAPTCHA | 2-3 days |
| Phase 3 | Debug Dashboard | 2-3 days |
| Phase 4 | Embed Support | 1-2 days |
| Security Review | Prep + Submit | 2-4 weeks |
| **Total to Launch** | | **6-10 weeks** |

---

## Success Metrics

### Technical
- Form submission success rate > 99%
- Average submission time < 3 seconds
- Error rate < 1%
- Test coverage > 85%

### Business
- AppExchange installs
- Trial to paid conversion rate
- Customer retention rate
- Support ticket volume
