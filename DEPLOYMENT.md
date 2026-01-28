# Deployment Instructions

## Prerequisites

1. Salesforce CLI (sf) installed
2. Access to a Salesforce org (Developer Edition or Sandbox)
3. Git installed

## Quick Start

### 1. Authenticate to Your Org

```bash
# Login to your Salesforce org
sf org login web --alias myorg

# Or for sandbox
sf org login web --alias myorg --instance-url https://test.salesforce.com
```

### 2. Deploy the Code

```bash
# Deploy to your org
sf project deploy start --target-org myorg

# Run tests
sf apex run test --target-org myorg --test-level RunLocalTests --code-coverage
```

### 3. Create Test Data

After deployment, create test data in Salesforce Setup:

#### Create a Form Record
1. Go to Setup → Object Manager → Form → Tab Settings → Enable tab
2. Go to App Launcher → Forms
3. Click New
4. Fill in:
   - Form Name: `support`
   - Title: `Contact Support`
   - Description: `We'll get back to you within 24 hours.`
   - Success Message: `Thank you! Your case has been submitted.`
   - Active: ✓ (checked)
   - Enable File Upload: ✓ (checked)
   - Max File Size (MB): `10`
5. Save

#### Create Form Fields
Create these Form Field records linked to your Form:

| Field Label | Field Type | Case Field | Required | Sort Order |
|-------------|------------|------------|----------|------------|
| Your Name | Text | SuppliedName | Yes | 1 |
| Email Address | Email | SuppliedEmail | Yes | 2 |
| Subject | Text | Subject | Yes | 3 |
| Message | Textarea | Description | Yes | 4 |

### 4. Create Salesforce Site

1. Go to Setup → Sites
2. Click "New"
3. Configure:
   - Site Label: `Forms`
   - Site Name: `Forms`
   - Active Site Home Page: `CaseFormPage`
   - Default Web Address: Note this URL
4. Click Save
5. Click "Activate"

### 5. Configure Guest User Profile

1. On the Site detail page, click "Public Access Settings"
2. Edit the Guest User Profile
3. Set Object Permissions:
   - Form__c: Read
   - Form_Field__c: Read
   - Case: Create
   - ContentVersion: Create
   - ContentDocumentLink: Create
   - Error_Log__c: Create
4. Set Apex Class Access:
   - CaseFormController: Enabled
   - ErrorLogger: Enabled
5. Set Visualforce Page Access:
   - CaseFormPage: Enabled

### 6. Test the Form

1. Copy your Site URL (e.g., `https://yourorg.my.salesforce-sites.com/Forms`)
2. Open in incognito/private browser
3. Navigate to: `{SiteURL}/CaseFormPage?name=support`
4. Fill out the form and submit
5. Verify:
   - Case is created in Salesforce
   - File is attached (if uploaded)
   - Success message is shown

## Troubleshooting

### Form shows "Form Not Available"
- Verify the form record exists with `Form_Name__c = 'support'`
- Verify `Active__c = true`
- Check Guest User has Read access to Form__c

### Form submission fails
1. Check Error_Log__c for error details
2. Verify Guest User permissions
3. Enable debug logs for the Guest User

### File upload fails
- Verify Guest User has Create access to ContentVersion
- Check file size is under the limit
- Verify the form has `Enable_File_Upload__c = true`

## Project Structure

```
force-app/main/default/
├── objects/
│   ├── Form__c/          # Form configuration
│   ├── Form_Field__c/    # Field definitions
│   └── Error_Log__c/     # Error logging
├── classes/
│   ├── CaseFormController.cls
│   ├── ErrorLogger.cls
│   └── *Test.cls
├── pages/
│   └── CaseFormPage.page
├── staticresources/
│   ├── caseFormStyles.css
│   └── caseFormScript.js
└── permissionsets/
    └── Web_to_Case_Admin.permissionset-meta.xml
```
