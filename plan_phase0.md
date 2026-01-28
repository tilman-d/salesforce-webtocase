# Phase 0: MVP - Web-to-Case with Attachments

## Context for Future Sessions

This is a **Salesforce AppExchange app** that creates public web forms for Case submission with file attachments. The app will be sold on AppExchange.

**Tech stack:** Salesforce (Apex, Visualforce, Custom Objects)
**Target:** Salesforce orgs with Service Cloud

## Goal

Prove the core functionality works before building the UI:
- Public user fills out a form
- Case is created in Salesforce
- Files are attached to the Case

**No LWC admin UI in this phase.** Forms are created manually via Salesforce Setup.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  CUSTOMER'S SALESFORCE ORG                  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           SALESFORCE SITE (Public, No Login)          │  │
│  │                                                       │  │
│  │  CaseFormPage.page (Visualforce)                      │  │
│  │  ├── Loads form config from Form__c                   │  │
│  │  ├── Renders fields from Form_Field__c               │  │
│  │  ├── Handles file upload                              │  │
│  │  └── Submits via CaseFormController                   │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 CaseFormController.cls                │  │
│  │  ├── getForm(formName) → Form__c                      │  │
│  │  ├── getFields(formId) → List<Form_Field__c>         │  │
│  │  └── submitForm(data, files) → Case + Attachments     │  │
│  └───────────────────────────────────────────────────────┘  │
│                              │                              │
│                              ▼                              │
│  ┌────────────┐  ┌─────────────────┐  ┌────────────────┐   │
│  │  Form__c   │  │ Form_Field__c   │  │ Error_Log__c   │   │
│  │  (config)  │  │ (field defs)    │  │ (debug)        │   │
│  └────────────┘  └─────────────────┘  └────────────────┘   │
│                                                             │
│  URL: https://[domain].my.salesforce-sites.com/CaseFormPage │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Model

### Form__c (Custom Object)
Stores form configuration. One record per form.

```
Fields:
├── Name (Auto-number) - Internal ID like "F-00001"
├── Form_Name__c (Text 80) - URL-friendly name like "support"
├── Title__c (Text 255) - Display title like "Contact Support"
├── Description__c (Long Text Area) - Intro text shown above form
├── Success_Message__c (Long Text Area) - Shown after successful submit
├── Active__c (Checkbox) - Enable/disable form
├── Enable_File_Upload__c (Checkbox) - Allow file attachments
└── Max_File_Size_MB__c (Number) - Max file size, default 10
```

### Form_Field__c (Custom Object)
Stores field definitions. Multiple records per form.

```
Fields:
├── Form__c (Master-Detail to Form__c) - Parent form
├── Field_Label__c (Text 255) - Label shown to user
├── Field_Type__c (Picklist) - Values: Text, Email, Textarea
├── Case_Field__c (Picklist) - Maps to: Subject, Description, SuppliedName, SuppliedEmail, SuppliedPhone
├── Required__c (Checkbox) - Is field required
└── Sort_Order__c (Number) - Display sequence (1, 2, 3...)
```

### Error_Log__c (Custom Object)
Stores errors for debugging. Created automatically on failures.

```
Fields:
├── Timestamp__c (DateTime) - When error occurred
├── Error_Message__c (Long Text Area) - Error description
├── Stack_Trace__c (Long Text Area) - Apex stack trace
└── Form_Id__c (Text 18) - Which form had the error
```

---

## Files to Create

### Directory Structure
```
force-app/main/default/
├── objects/
│   ├── Form__c/
│   │   ├── Form__c.object-meta.xml
│   │   └── fields/
│   │       ├── Form_Name__c.field-meta.xml
│   │       ├── Title__c.field-meta.xml
│   │       ├── Description__c.field-meta.xml
│   │       ├── Success_Message__c.field-meta.xml
│   │       ├── Active__c.field-meta.xml
│   │       ├── Enable_File_Upload__c.field-meta.xml
│   │       └── Max_File_Size_MB__c.field-meta.xml
│   ├── Form_Field__c/
│   │   ├── Form_Field__c.object-meta.xml
│   │   └── fields/
│   │       ├── Form__c.field-meta.xml
│   │       ├── Field_Label__c.field-meta.xml
│   │       ├── Field_Type__c.field-meta.xml
│   │       ├── Case_Field__c.field-meta.xml
│   │       ├── Required__c.field-meta.xml
│   │       └── Sort_Order__c.field-meta.xml
│   └── Error_Log__c/
│       ├── Error_Log__c.object-meta.xml
│       └── fields/
│           ├── Timestamp__c.field-meta.xml
│           ├── Error_Message__c.field-meta.xml
│           ├── Stack_Trace__c.field-meta.xml
│           └── Form_Id__c.field-meta.xml
├── classes/
│   ├── CaseFormController.cls
│   ├── CaseFormController.cls-meta.xml
│   ├── ErrorLogger.cls
│   ├── ErrorLogger.cls-meta.xml
│   ├── CaseFormControllerTest.cls
│   └── CaseFormControllerTest.cls-meta.xml
├── pages/
│   ├── CaseFormPage.page
│   └── CaseFormPage.page-meta.xml
├── staticresources/
│   ├── caseFormStyles.resource-meta.xml
│   ├── caseFormStyles.css
│   ├── caseFormScript.resource-meta.xml
│   └── caseFormScript.js
└── permissionsets/
    └── Web_to_Case_Admin.permissionset-meta.xml
```

---

## Implementation Details

### ErrorLogger.cls
Simple error logging utility.

```apex
public class ErrorLogger {

    public static void log(String message, String stackTrace, String formId) {
        try {
            insert new Error_Log__c(
                Timestamp__c = DateTime.now(),
                Error_Message__c = message,
                Stack_Trace__c = stackTrace,
                Form_Id__c = formId
            );
        } catch (Exception e) {
            System.debug('ErrorLogger failed: ' + e.getMessage());
        }
    }

    public static void logException(Exception e, String formId) {
        log(e.getMessage(), e.getStackTraceString(), formId);
    }
}
```

### CaseFormController.cls
Main controller for the Visualforce page.

```apex
public without sharing class CaseFormController {

    public Form__c form { get; set; }
    public List<Form_Field__c> fields { get; set; }
    public String formName { get; set; }

    public CaseFormController() {
        formName = ApexPages.currentPage().getParameters().get('name');
        loadForm();
    }

    private void loadForm() {
        if (String.isBlank(formName)) return;

        List<Form__c> forms = [
            SELECT Id, Form_Name__c, Title__c, Description__c,
                   Success_Message__c, Active__c, Enable_File_Upload__c,
                   Max_File_Size_MB__c
            FROM Form__c
            WHERE Form_Name__c = :formName AND Active__c = true
            LIMIT 1
        ];

        if (!forms.isEmpty()) {
            form = forms[0];
            fields = [
                SELECT Id, Field_Label__c, Field_Type__c, Case_Field__c,
                       Required__c, Sort_Order__c
                FROM Form_Field__c
                WHERE Form__c = :form.Id
                ORDER BY Sort_Order__c ASC
            ];
        }
    }

    @RemoteAction
    global static Map<String, Object> submitForm(String formId, Map<String, String> fieldValues, String fileName, String fileContent) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Create Case
            Case c = new Case();
            c.Origin = 'Web Form';

            // Map field values to Case fields
            for (String caseField : fieldValues.keySet()) {
                if (caseField == 'Subject') c.Subject = fieldValues.get(caseField);
                if (caseField == 'Description') c.Description = fieldValues.get(caseField);
                if (caseField == 'SuppliedName') c.SuppliedName = fieldValues.get(caseField);
                if (caseField == 'SuppliedEmail') c.SuppliedEmail = fieldValues.get(caseField);
                if (caseField == 'SuppliedPhone') c.SuppliedPhone = fieldValues.get(caseField);
            }

            insert c;

            // Attach file if provided
            if (String.isNotBlank(fileName) && String.isNotBlank(fileContent)) {
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = EncodingUtil.base64Decode(fileContent);
                insert cv;

                // Link to Case
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
                cdl.LinkedEntityId = c.Id;
                cdl.ShareType = 'V';
                insert cdl;
            }

            result.put('success', true);
            result.put('caseNumber', [SELECT CaseNumber FROM Case WHERE Id = :c.Id].CaseNumber);

        } catch (Exception e) {
            ErrorLogger.logException(e, formId);
            result.put('success', false);
            result.put('error', e.getMessage());
        }

        return result;
    }
}
```

### CaseFormPage.page (Visualforce)
Public-facing form page.

```html
<apex:page controller="CaseFormController" showHeader="false" sidebar="false"
           standardStylesheets="false" docType="html-5.0" applyBodyTag="false">

    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <apex:stylesheet value="{!$Resource.caseFormStyles}"/>
    </head>
    <body>
        <div class="form-container">
            <apex:outputPanel rendered="{!form != null}">
                <h1>{!form.Title__c}</h1>
                <p class="description">{!form.Description__c}</p>

                <form id="caseForm">
                    <apex:repeat value="{!fields}" var="field">
                        <div class="form-field">
                            <label>
                                {!field.Field_Label__c}
                                <apex:outputPanel rendered="{!field.Required__c}">
                                    <span class="required">*</span>
                                </apex:outputPanel>
                            </label>

                            <apex:outputPanel rendered="{!field.Field_Type__c == 'Text' || field.Field_Type__c == 'Email'}">
                                <input type="{!IF(field.Field_Type__c == 'Email', 'email', 'text')}"
                                       name="{!field.Case_Field__c}"
                                       data-required="{!field.Required__c}"
                                       class="form-input"/>
                            </apex:outputPanel>

                            <apex:outputPanel rendered="{!field.Field_Type__c == 'Textarea'}">
                                <textarea name="{!field.Case_Field__c}"
                                          data-required="{!field.Required__c}"
                                          class="form-input" rows="4"></textarea>
                            </apex:outputPanel>
                        </div>
                    </apex:repeat>

                    <apex:outputPanel rendered="{!form.Enable_File_Upload__c}">
                        <div class="form-field">
                            <label>Attachment</label>
                            <input type="file" id="fileInput" class="form-input"/>
                            <p class="help-text">Max size: {!form.Max_File_Size_MB__c} MB</p>
                        </div>
                    </apex:outputPanel>

                    <button type="submit" class="submit-button">Submit</button>
                </form>

                <div id="successMessage" class="success-message" style="display:none;">
                    {!form.Success_Message__c}
                </div>

                <div id="errorMessage" class="error-message" style="display:none;"></div>
            </apex:outputPanel>

            <apex:outputPanel rendered="{!form == null}">
                <p class="error-message">Form not found or inactive.</p>
            </apex:outputPanel>
        </div>

        <script>
            var formId = '{!form.Id}';
            var maxFileSize = {!IF(form.Max_File_Size_MB__c == null, 10, form.Max_File_Size_MB__c)} * 1024 * 1024;
        </script>
        <apex:includeScript value="{!$Resource.caseFormScript}"/>
    </body>
    </html>
</apex:page>
```

### caseFormScript.js
Client-side validation and submission.

```javascript
document.addEventListener('DOMContentLoaded', function() {
    var form = document.getElementById('caseForm');
    if (!form) return;

    form.addEventListener('submit', function(e) {
        e.preventDefault();

        // Validate required fields
        var errors = [];
        var inputs = form.querySelectorAll('[data-required="true"]');
        inputs.forEach(function(input) {
            if (!input.value.trim()) {
                errors.push(input.previousElementSibling.textContent.replace('*', '').trim() + ' is required');
                input.classList.add('error');
            } else {
                input.classList.remove('error');
            }
        });

        if (errors.length > 0) {
            showError(errors.join('<br/>'));
            return;
        }

        // Collect field values
        var fieldValues = {};
        form.querySelectorAll('input[name], textarea[name]').forEach(function(input) {
            if (input.type !== 'file') {
                fieldValues[input.name] = input.value;
            }
        });

        // Handle file
        var fileInput = document.getElementById('fileInput');
        var fileName = '';
        var fileContent = '';

        if (fileInput && fileInput.files.length > 0) {
            var file = fileInput.files[0];

            if (file.size > maxFileSize) {
                showError('File size exceeds maximum allowed.');
                return;
            }

            var reader = new FileReader();
            reader.onload = function(e) {
                var base64 = e.target.result.split(',')[1];
                submitToSalesforce(fieldValues, file.name, base64);
            };
            reader.readAsDataURL(file);
        } else {
            submitToSalesforce(fieldValues, '', '');
        }
    });

    function submitToSalesforce(fieldValues, fileName, fileContent) {
        var submitButton = form.querySelector('.submit-button');
        submitButton.disabled = true;
        submitButton.textContent = 'Submitting...';

        Visualforce.remoting.Manager.invokeAction(
            '{!$RemoteAction.CaseFormController.submitForm}',
            formId, fieldValues, fileName, fileContent,
            function(result, event) {
                submitButton.disabled = false;
                submitButton.textContent = 'Submit';

                if (event.status && result.success) {
                    form.style.display = 'none';
                    document.getElementById('successMessage').style.display = 'block';
                } else {
                    showError(result.error || 'An error occurred. Please try again.');
                }
            },
            { escape: false }
        );
    }

    function showError(message) {
        var errorDiv = document.getElementById('errorMessage');
        errorDiv.innerHTML = message;
        errorDiv.style.display = 'block';
    }
});
```

### caseFormStyles.css
Minimal clean styling.

```css
* {
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f5f5f5;
    margin: 0;
    padding: 20px;
}

.form-container {
    max-width: 600px;
    margin: 0 auto;
    background: white;
    padding: 40px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

h1 {
    margin: 0 0 10px 0;
    font-size: 24px;
    color: #333;
}

.description {
    color: #666;
    margin-bottom: 30px;
}

.form-field {
    margin-bottom: 20px;
}

label {
    display: block;
    margin-bottom: 5px;
    font-weight: 500;
    color: #333;
}

.required {
    color: #e74c3c;
}

.form-input {
    width: 100%;
    padding: 10px 12px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 16px;
}

.form-input:focus {
    outline: none;
    border-color: #0070d2;
}

.form-input.error {
    border-color: #e74c3c;
}

.help-text {
    font-size: 12px;
    color: #888;
    margin-top: 5px;
}

.submit-button {
    width: 100%;
    padding: 12px;
    background: #0070d2;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 16px;
    cursor: pointer;
}

.submit-button:hover {
    background: #005fb2;
}

.submit-button:disabled {
    background: #ccc;
    cursor: not-allowed;
}

.success-message {
    padding: 20px;
    background: #d4edda;
    color: #155724;
    border-radius: 4px;
    text-align: center;
}

.error-message {
    padding: 15px;
    background: #f8d7da;
    color: #721c24;
    border-radius: 4px;
    margin-bottom: 20px;
}
```

---

## Testing the MVP

### Step 1: Deploy to Scratch Org
```bash
sf project deploy start
sf org open
```

### Step 2: Create Test Data in Salesforce Setup

**Create Form__c record:**
- Form_Name__c: `support`
- Title__c: `Contact Support`
- Description__c: `We'll get back to you within 24 hours.`
- Success_Message__c: `Thank you! Your case has been submitted.`
- Active__c: `true`
- Enable_File_Upload__c: `true`
- Max_File_Size_MB__c: `10`

**Create Form_Field__c records:**

| Field_Label__c | Field_Type__c | Case_Field__c | Required__c | Sort_Order__c |
|----------------|---------------|---------------|-------------|---------------|
| Your Name | Text | SuppliedName | true | 1 |
| Email Address | Email | SuppliedEmail | true | 2 |
| Subject | Text | Subject | true | 3 |
| Message | Textarea | Description | true | 4 |

### Step 3: Create Salesforce Site
1. Setup → Sites → New
2. Site Label: `Forms`
3. Site Name: `Forms`
4. Active Site Home Page: `CaseFormPage`
5. Click Save, then Activate

### Step 4: Configure Guest User Profile
1. On Site detail page → Public Access Settings
2. Edit the Guest User Profile
3. **Object Permissions:**
   - Form__c: Read
   - Form_Field__c: Read
   - Case: Create
   - ContentVersion: Create
   - ContentDocumentLink: Create
   - Error_Log__c: Create
4. **Apex Class Access:** CaseFormController, ErrorLogger
5. **Visualforce Page Access:** CaseFormPage

### Step 5: Test
1. Open incognito browser
2. Go to: `https://[your-domain].my.salesforce-sites.com/Forms/CaseFormPage?name=support`
3. Fill out all fields
4. Attach a file
5. Submit
6. Verify:
   - [ ] Case created with correct values
   - [ ] File attached to Case
   - [ ] Success message displayed

---

## Success Criteria

Phase 0 is complete when:
1. Form renders correctly on public Site
2. Case is created with mapped field values
3. File is attached to the Case
4. Errors are logged to Error_Log__c
5. Tests pass with 75%+ coverage

---

## Next Phase

After Phase 0 is validated, proceed to **Phase 1** to add the admin UI (LWC form builder).
