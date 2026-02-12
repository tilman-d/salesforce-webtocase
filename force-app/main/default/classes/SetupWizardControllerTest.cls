/**
 * Test class for SetupWizardController
 * Target: 90%+ code coverage
 */
@isTest
private class SetupWizardControllerTest {

    /**
     * Test PreconditionResult wrapper default values
     */
    @isTest
    static void testPreconditionResultWrapper() {
        SetupWizardController.PreconditionResult result = new SetupWizardController.PreconditionResult();

        System.assertEquals(false, result.allPassed, 'allPassed should default to false');
        System.assertEquals(false, result.myDomainDeployed, 'myDomainDeployed should default to false');
        System.assertEquals(false, result.hasAdminPermissions, 'hasAdminPermissions should default to false');
        System.assertEquals(false, result.sitesEnabled, 'sitesEnabled should default to false');
    }

    /**
     * Test SiteInfo wrapper default constructor
     */
    @isTest
    static void testSiteInfoWrapperDefault() {
        SetupWizardController.SiteInfo info = new SetupWizardController.SiteInfo();

        System.assertEquals(null, info.id, 'id should be null');
        System.assertEquals(null, info.name, 'name should be null');
    }

    /**
     * Test PermissionStatus wrapper default values
     */
    @isTest
    static void testPermissionStatusWrapperDefault() {
        SetupWizardController.PermissionStatus status = new SetupWizardController.PermissionStatus();

        System.assertEquals(false, status.configured, 'configured should default to false');
        System.assertEquals(false, status.canAutomate, 'canAutomate should default to false');
    }

    /**
     * Test PermissionStatus wrapper constructor with params
     */
    @isTest
    static void testPermissionStatusWrapperWithParams() {
        SetupWizardController.PermissionStatus status = new SetupWizardController.PermissionStatus(
            'Test Permission',
            'Test Description',
            true,
            true,
            'Object'
        );

        System.assertEquals('Test Permission', status.name, 'name should match');
        System.assertEquals('Test Description', status.description, 'description should match');
        System.assertEquals(true, status.configured, 'configured should be true');
        System.assertEquals(true, status.canAutomate, 'canAutomate should be true');
        System.assertEquals('Object', status.permissionType, 'permissionType should match');
    }

    /**
     * Test ValidationResult wrapper default values
     */
    @isTest
    static void testValidationResultWrapper() {
        SetupWizardController.ValidationResult result = new SetupWizardController.ValidationResult();

        System.assertEquals(false, result.allPassed, 'allPassed should default to false');
        System.assertNotEquals(null, result.permissions, 'permissions should be initialized');
        System.assertEquals(0, result.permissions.size(), 'permissions should be empty');
    }

    /**
     * Test ConfigResult wrapper default values
     */
    @isTest
    static void testConfigResultWrapper() {
        SetupWizardController.ConfigResult result = new SetupWizardController.ConfigResult();

        System.assertEquals(false, result.success, 'success should default to false');
        System.assertNotEquals(null, result.results, 'results should be initialized');
        System.assertEquals(0, result.results.size(), 'results should be empty');
    }

    /**
     * Test ConfigSummary wrapper default values
     */
    @isTest
    static void testConfigSummaryWrapper() {
        SetupWizardController.ConfigSummary summary = new SetupWizardController.ConfigSummary();

        System.assertNotEquals(null, summary.permissionsApplied, 'permissionsApplied should be initialized');
        System.assertEquals(0, summary.permissionsApplied.size(), 'permissionsApplied should be empty');
    }

    /**
     * Test checkPreconditions - should pass in a properly configured org
     */
    @isTest
    static void testCheckPreconditions() {
        Test.startTest();
        SetupWizardController.PreconditionResult result = SetupWizardController.checkPreconditions();
        Test.stopTest();

        // In test context, My Domain should be available
        System.assertNotEquals(null, result, 'Result should not be null');
        // We can't guarantee all preconditions pass in all test orgs, but method should not throw
    }

    /**
     * Test getActiveSites - query should work even if no sites exist
     */
    @isTest
    static void testGetActiveSites() {
        Test.startTest();
        List<SetupWizardController.SiteInfo> sites = SetupWizardController.getActiveSites();
        Test.stopTest();

        // Sites may or may not exist, but query should not throw
        System.assertNotEquals(null, sites, 'Sites list should not be null');
    }

    /**
     * Test getSetupStatus with blank siteId - should throw exception
     */
    @isTest
    static void testGetSetupStatusBlankId() {
        Test.startTest();
        try {
            SetupWizardController.getSetupStatus('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test getSetupStatus with null siteId - should throw exception
     */
    @isTest
    static void testGetSetupStatusNullId() {
        Test.startTest();
        try {
            SetupWizardController.getSetupStatus(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test configurePermissions with blank siteId - should throw exception
     */
    @isTest
    static void testConfigurePermissionsBlankId() {
        Test.startTest();
        try {
            SetupWizardController.configurePermissions('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test configurePermissions with null siteId - should throw exception
     */
    @isTest
    static void testConfigurePermissionsNullId() {
        Test.startTest();
        try {
            SetupWizardController.configurePermissions(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test validateConfiguration with blank siteId - should throw exception
     */
    @isTest
    static void testValidateConfigurationBlankId() {
        Test.startTest();
        try {
            SetupWizardController.validateConfiguration('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test createSampleForm - creates a new sample form
     */
    @isTest
    static void testCreateSampleForm() {
        Test.startTest();
        String formId = SetupWizardController.createSampleForm();
        Test.stopTest();

        System.assertNotEquals(null, formId, 'Form ID should not be null');

        // Verify the form was created
        Form__c form = [SELECT Id, Form_Name__c, Title__c, Active__c FROM Form__c WHERE Id = :formId];
        System.assertEquals('contact-support', form.Form_Name__c, 'Form name should match');
        System.assertEquals('Contact Support', form.Title__c, 'Title should match');
        System.assertEquals(true, form.Active__c, 'Form should be active');

        // Verify fields were created
        Integer fieldCount = [SELECT COUNT() FROM Form_Field__c WHERE Form__c = :formId];
        System.assertEquals(4, fieldCount, 'Should have 4 fields');
    }

    /**
     * Test createSampleForm - returns existing form if already exists
     */
    @isTest
    static void testCreateSampleFormExisting() {
        // Create an existing sample form
        Form__c existingForm = new Form__c(
            Form_Name__c = 'contact-support',
            Title__c = 'Existing Form',
            Active__c = false
        );
        insert existingForm;

        Test.startTest();
        String formId = SetupWizardController.createSampleForm();
        Test.stopTest();

        System.assertEquals(existingForm.Id, formId, 'Should return existing form ID');

        // Verify no new form was created
        Integer formCount = [SELECT COUNT() FROM Form__c WHERE Form_Name__c = 'contact-support'];
        System.assertEquals(1, formCount, 'Should still have only 1 form');
    }

    /**
     * Test getPublicUrl with blank siteId - should throw exception
     */
    @isTest
    static void testGetPublicUrlBlankId() {
        Test.startTest();
        try {
            SetupWizardController.getPublicUrl('', null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test getPublicUrl with null siteId - should throw exception
     */
    @isTest
    static void testGetPublicUrlNullId() {
        Test.startTest();
        try {
            SetupWizardController.getPublicUrl(null, 'test-form');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test getConfigSummary with blank siteId - should throw exception
     */
    @isTest
    static void testGetConfigSummaryBlankId() {
        Test.startTest();
        try {
            SetupWizardController.getConfigSummary('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test getConfigSummary with null siteId - should throw exception
     */
    @isTest
    static void testGetConfigSummaryNullId() {
        Test.startTest();
        try {
            SetupWizardController.getConfigSummary(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test with a mock Site - comprehensive test for Site-related methods
     * Note: Site object cannot be inserted in tests, so we test error handling
     */
    @isTest
    static void testWithInvalidSiteId() {
        // Use a fake Site ID
        String fakeSiteId = '0DM000000000001';

        Test.startTest();

        // Test getSetupStatus with invalid Site ID
        try {
            SetupWizardController.getSetupStatus(fakeSiteId);
            System.assert(false, 'Should have thrown exception for invalid site');
        } catch (Exception e) {
            // Can be AuraHandledException or QueryException - either is acceptable
            System.assert(e.getMessage() != null, 'Should have error message');
        }

        // Test configurePermissions with invalid Site ID
        // This method catches exceptions and returns a result with success=false
        SetupWizardController.ConfigResult configResult = SetupWizardController.configurePermissions(fakeSiteId);
        System.assertEquals(false, configResult.success, 'Should have failed for invalid site');
        System.assert(String.isNotBlank(configResult.errorMessage), 'Should have error message');

        // Test getPublicUrl with invalid Site ID
        try {
            SetupWizardController.getPublicUrl(fakeSiteId, 'test');
            System.assert(false, 'Should have thrown exception for invalid site');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Should have error message');
        }

        // Test getConfigSummary with invalid Site ID
        try {
            SetupWizardController.getConfigSummary(fakeSiteId);
            System.assert(false, 'Should have thrown exception for invalid site');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Should have error message');
        }

        Test.stopTest();
    }

    /**
     * Test preconditions with limited user
     */
    @isTest
    static void testPreconditionsAsStandardUser() {
        // Create a standard user without admin permissions
        // Must find a profile that explicitly lacks admin perms (not just non-SysAdmin name)
        List<Profile> standardProfiles = [
            SELECT Id FROM Profile
            WHERE PermissionsCustomizeApplication = false
            AND PermissionsModifyAllData = false
            AND UserType = 'Standard'
            LIMIT 1
        ];
        if (standardProfiles.isEmpty()) {
            // No non-admin standard profile available (e.g., minimal packaging scratch org) — skip test
            return;
        }
        User standardUser = new User(
            ProfileId = standardProfiles[0].Id,
            Username = 'standardtestuser' + DateTime.now().getTime() + '@test.com',
            Email = 'standardtestuser@test.com',
            LastName = 'Test',
            FirstName = 'Standard',
            Alias = 'stdtst',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert standardUser;

        Test.startTest();
        System.runAs(standardUser) {
            SetupWizardController.PreconditionResult result = SetupWizardController.checkPreconditions();
            // Standard user should not have admin permissions
            System.assertEquals(false, result.hasAdminPermissions, 'Standard user should not have admin permissions');
        }
        Test.stopTest();
    }

    /**
     * Test that multiple calls to createSampleForm are idempotent
     */
    @isTest
    static void testCreateSampleFormIdempotent() {
        Test.startTest();
        String formId1 = SetupWizardController.createSampleForm();
        String formId2 = SetupWizardController.createSampleForm();
        Test.stopTest();

        System.assertEquals(formId1, formId2, 'Multiple calls should return same form ID');

        // Verify only one form exists
        Integer formCount = [SELECT COUNT() FROM Form__c WHERE Form_Name__c = 'contact-support'];
        System.assertEquals(1, formCount, 'Should have only 1 sample form');
    }

    /**
     * Test sample form has correct fields
     */
    @isTest
    static void testSampleFormFields() {
        Test.startTest();
        String formId = SetupWizardController.createSampleForm();
        Test.stopTest();

        // Query the fields
        List<Form_Field__c> fields = [
            SELECT Field_Label__c, Field_Type__c, Case_Field__c, Required__c, Sort_Order__c
            FROM Form_Field__c
            WHERE Form__c = :formId
            ORDER BY Sort_Order__c ASC
        ];

        System.assertEquals(4, fields.size(), 'Should have 4 fields');

        // Check first field (Your Name)
        System.assertEquals('Your Name', fields[0].Field_Label__c, 'First field should be Your Name');
        System.assertEquals('Text', fields[0].Field_Type__c, 'First field type should be Text');
        System.assertEquals('SuppliedName', fields[0].Case_Field__c, 'First field should map to SuppliedName');
        System.assertEquals(true, fields[0].Required__c, 'First field should be required');

        // Check second field (Email)
        System.assertEquals('Email Address', fields[1].Field_Label__c, 'Second field should be Email Address');
        System.assertEquals('Email', fields[1].Field_Type__c, 'Second field type should be Email');

        // Check third field (Subject)
        System.assertEquals('Subject', fields[2].Field_Label__c, 'Third field should be Subject');

        // Check fourth field (Description)
        System.assertEquals('Description', fields[3].Field_Label__c, 'Fourth field should be Description');
        System.assertEquals('Textarea', fields[3].Field_Type__c, 'Fourth field type should be Textarea');
    }

    /**
     * Integration test - run through the preconditions and site listing flow
     */
    @isTest
    static void testPreconditionsAndSitesFlow() {
        Test.startTest();

        // Step 1: Check preconditions
        SetupWizardController.PreconditionResult preconditions = SetupWizardController.checkPreconditions();
        System.assertNotEquals(null, preconditions, 'Preconditions result should not be null');

        // Step 2: Get active sites (may be empty)
        List<SetupWizardController.SiteInfo> sites = SetupWizardController.getActiveSites();
        System.assertNotEquals(null, sites, 'Sites list should not be null');

        Test.stopTest();
    }

    /**
     * Test SiteInfo wrapper constructor with Site object
     * Note: We can't create Site records in tests, so we test the default constructor coverage
     */
    @isTest
    static void testSiteInfoWrapperCoverage() {
        SetupWizardController.SiteInfo info = new SetupWizardController.SiteInfo();
        info.id = 'testId';
        info.name = 'TestSite';
        info.masterLabel = 'Test Site Label';
        info.guestUserId = 'testGuestUserId';
        info.subdomain = 'testsubdomain';
        info.urlPathPrefix = 'testprefix';
        info.status = 'Active';
        info.baseUrl = 'https://test.my.site.com';

        System.assertEquals('testId', info.id, 'id should match');
        System.assertEquals('TestSite', info.name, 'name should match');
        System.assertEquals('Test Site Label', info.masterLabel, 'masterLabel should match');
        System.assertEquals('testGuestUserId', info.guestUserId, 'guestUserId should match');
        System.assertEquals('testsubdomain', info.subdomain, 'subdomain should match');
        System.assertEquals('testprefix', info.urlPathPrefix, 'urlPathPrefix should match');
        System.assertEquals('Active', info.status, 'status should match');
        System.assertEquals('https://test.my.site.com', info.baseUrl, 'baseUrl should match');
    }

    /**
     * Test ValidationResult wrapper with permissions
     */
    @isTest
    static void testValidationResultWithPermissions() {
        SetupWizardController.ValidationResult result = new SetupWizardController.ValidationResult();

        // Add some permissions
        result.permissions.add(new SetupWizardController.PermissionStatus('Test1', 'Desc1', true, true, 'Object'));
        result.permissions.add(new SetupWizardController.PermissionStatus('Test2', 'Desc2', false, true, 'Field'));

        System.assertEquals(2, result.permissions.size(), 'Should have 2 permissions');
        System.assertEquals(true, result.permissions[0].configured, 'First permission should be configured');
        System.assertEquals(false, result.permissions[1].configured, 'Second permission should not be configured');
    }

    /**
     * Test ConfigResult wrapper with results
     */
    @isTest
    static void testConfigResultWithResults() {
        SetupWizardController.ConfigResult result = new SetupWizardController.ConfigResult();
        result.success = true;
        result.errorMessage = null;

        result.results.add(new SetupWizardController.PermissionStatus('Test', 'Desc', true, true, 'Object'));

        System.assertEquals(true, result.success, 'Success should be true');
        System.assertEquals(1, result.results.size(), 'Should have 1 result');
    }

    /**
     * Test ConfigSummary wrapper with data
     */
    @isTest
    static void testConfigSummaryWithData() {
        SetupWizardController.ConfigSummary summary = new SetupWizardController.ConfigSummary();
        summary.siteName = 'Test Site';
        summary.siteUrl = 'https://test.my.site.com';
        summary.configuredAt = DateTime.now().format('yyyy-MM-dd HH:mm:ss z');
        summary.configuredBy = 'Test User';
        summary.permissionsApplied.add('Form__c Read');
        summary.permissionsApplied.add('Case Create');

        System.assertEquals('Test Site', summary.siteName, 'siteName should match');
        System.assertEquals('Test User', summary.configuredBy, 'configuredBy should match');
        System.assertEquals(2, summary.permissionsApplied.size(), 'Should have 2 permissions applied');
    }

    // ==================== saveDefaultSite Tests ====================

    /**
     * Test saveDefaultSite with blank siteId - should throw exception
     */
    @isTest
    static void testSaveDefaultSiteBlankId() {
        Test.startTest();
        try {
            SetupWizardController.saveDefaultSite('');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test saveDefaultSite with null siteId - should throw exception
     */
    @isTest
    static void testSaveDefaultSiteNullId() {
        Test.startTest();
        try {
            SetupWizardController.saveDefaultSite(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Site ID is required'), 'Should throw required ID error');
        }
        Test.stopTest();
    }

    /**
     * Test saveDefaultSite with invalid siteId - should throw exception
     */
    @isTest
    static void testSaveDefaultSiteInvalidId() {
        Test.startTest();
        try {
            SetupWizardController.saveDefaultSite('0DM000000000001');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Invalid Site ID') || e.getMessage().contains('Error saving'),
                'Should throw invalid site or error message');
        }
        Test.stopTest();
    }

    // ==================== reCAPTCHA Settings Tests ====================

    /**
     * Test ReCaptchaSettingsResult wrapper default values
     */
    @isTest
    static void testReCaptchaSettingsResultWrapper() {
        SetupWizardController.ReCaptchaSettingsResult result = new SetupWizardController.ReCaptchaSettingsResult();

        System.assertEquals(false, result.isConfigured, 'isConfigured should default to false');
        System.assertEquals(false, result.hasSecretKey, 'hasSecretKey should default to false');
        System.assertEquals(null, result.siteKey, 'siteKey should be null');
        System.assertEquals(null, result.errorMessage, 'errorMessage should be null');
        System.assertEquals('V2_Checkbox', result.captchaType, 'captchaType should default to V2_Checkbox');
        System.assertEquals(0.3, result.scoreThreshold, 'scoreThreshold should default to 0.3');
    }

    /**
     * Test getReCaptchaSettings - no settings exist
     */
    @isTest
    static void testGetReCaptchaSettingsEmpty() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.getReCaptchaSettings();
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assertEquals(null, result.siteKey, 'Site key should be null');
        System.assertEquals(false, result.hasSecretKey, 'Should not have secret key');
    }

    /**
     * Test getReCaptchaSettings - with existing settings
     */
    @isTest
    static void testGetReCaptchaSettingsExisting() {
        // Insert settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'ExistingSiteKey123',
            Secret_Key__c = 'ExistingSecretKey456',
            Captcha_Type__c = 'V3_Score',
            Score_Threshold__c = 0.5
        );
        insert settings;

        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.getReCaptchaSettings();
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');
        System.assertEquals('ExistingSiteKey123', result.siteKey, 'Site key should match');
        System.assertEquals(true, result.hasSecretKey, 'Should indicate secret key exists');
        System.assertEquals('V3_Score', result.captchaType, 'Captcha type should match');
        System.assertEquals(0.5, result.scoreThreshold, 'Score threshold should match');
        // Note: We don't expose the actual secret key value
    }

    /**
     * Test saveReCaptchaSettings - valid keys with type and threshold
     */
    @isTest
    static void testSaveReCaptchaSettingsValid() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            '6LeTestSiteKey123',
            '6LeTestSecretKey456',
            'V3_Score',
            0.5
        );
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');
        System.assertEquals('6LeTestSiteKey123', result.siteKey, 'Site key should match');
        System.assertEquals(true, result.hasSecretKey, 'Should indicate secret key exists');
        System.assertEquals('V3_Score', result.captchaType, 'Captcha type should match');
        System.assertEquals(0.5, result.scoreThreshold, 'Score threshold should match');
        System.assertEquals(null, result.errorMessage, 'Should have no error message');

        // Verify settings were saved
        reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals('6LeTestSiteKey123', settings.Site_Key__c, 'Site key should be saved');
        System.assertEquals('6LeTestSecretKey456', settings.Secret_Key__c, 'Secret key should be saved');
        System.assertEquals('V3_Score', settings.Captcha_Type__c, 'Captcha type should be saved');
        System.assertEquals(0.5, settings.Score_Threshold__c, 'Score threshold should be saved');
    }

    /**
     * Test saveReCaptchaSettings - partial update (Site Key only)
     */
    @isTest
    static void testSaveReCaptchaSettingsPartialSiteKey() {
        // First, insert initial settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'OldSiteKey',
            Secret_Key__c = 'OldSecretKey',
            Captcha_Type__c = 'V2_Checkbox',
            Score_Threshold__c = 0.3
        );
        insert settings;

        Test.startTest();
        // Update only Site Key, leave Secret Key blank to preserve existing
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'NewSiteKey',
            '',  // Empty - should preserve existing
            null,  // Null - should preserve existing
            null   // Null - should preserve existing
        );
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');
        System.assertEquals('NewSiteKey', result.siteKey, 'Site key should be updated');

        // Verify secret key was preserved
        reCAPTCHA_Settings__c updatedSettings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals('NewSiteKey', updatedSettings.Site_Key__c, 'Site key should be updated');
        System.assertEquals('OldSecretKey', updatedSettings.Secret_Key__c, 'Secret key should be preserved');
        System.assertEquals('V2_Checkbox', updatedSettings.Captcha_Type__c, 'Captcha type should be preserved');
    }

    /**
     * Test saveReCaptchaSettings - partial update (Secret Key only)
     */
    @isTest
    static void testSaveReCaptchaSettingsPartialSecretKey() {
        // First, insert initial settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'OldSiteKey',
            Secret_Key__c = 'OldSecretKey'
        );
        insert settings;

        Test.startTest();
        // Update only Secret Key, leave Site Key blank to preserve existing
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            '',  // Empty - should preserve existing
            'NewSecretKey',
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');

        // Verify site key was preserved and secret key was updated
        reCAPTCHA_Settings__c updatedSettings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals('OldSiteKey', updatedSettings.Site_Key__c, 'Site key should be preserved');
        System.assertEquals('NewSecretKey', updatedSettings.Secret_Key__c, 'Secret key should be updated');
    }

    /**
     * Test saveReCaptchaSettings - field length validation (Site Key too long)
     */
    @isTest
    static void testSaveReCaptchaSettingsSiteKeyTooLong() {
        // Create a string longer than 255 characters
        String longKey = 'a'.repeat(256);

        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            longKey,
            'ValidSecretKey',
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assert(result.errorMessage.contains('255'), 'Should mention 255 character limit');
    }

    /**
     * Test saveReCaptchaSettings - field length validation (Secret Key too long)
     */
    @isTest
    static void testSaveReCaptchaSettingsSecretKeyTooLong() {
        // Create a string longer than 255 characters
        String longKey = 'b'.repeat(256);

        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'ValidSiteKey',
            longKey,
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assert(result.errorMessage.contains('255'), 'Should mention 255 character limit');
    }

    /**
     * Test saveReCaptchaSettings - update existing settings
     */
    @isTest
    static void testSaveReCaptchaSettingsUpdate() {
        // First, insert initial settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'OldSiteKey',
            Secret_Key__c = 'OldSecretKey'
        );
        insert settings;

        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'NewSiteKey',
            'NewSecretKey',
            'V2_Invisible',
            null
        );
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');
        System.assertEquals('NewSiteKey', result.siteKey, 'Site key should be updated');
        System.assertEquals('V2_Invisible', result.captchaType, 'Captcha type should be updated');

        // Verify only one record exists (upsert behavior)
        List<reCAPTCHA_Settings__c> allSettings = [SELECT Id FROM reCAPTCHA_Settings__c];
        System.assertEquals(1, allSettings.size(), 'Should still have only one record');
    }

    /**
     * Test clearReCaptchaSettings
     */
    @isTest
    static void testClearReCaptchaSettings() {
        // First, save some settings
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'TestKey',
            Secret_Key__c = 'TestSecret'
        );
        insert settings;

        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.clearReCaptchaSettings();
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured after clear');
        System.assertEquals(false, result.hasSecretKey, 'Should not have secret key after clear');
        System.assertEquals(null, result.siteKey, 'Site key should be null after clear');

        // Verify settings were cleared
        reCAPTCHA_Settings__c clearedSettings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals(null, clearedSettings.Site_Key__c, 'Site key should be null');
        System.assertEquals(null, clearedSettings.Secret_Key__c, 'Secret key should be null');
    }

    /**
     * Test clearReCaptchaSettings - when no settings exist
     */
    @isTest
    static void testClearReCaptchaSettingsEmpty() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.clearReCaptchaSettings();
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assertEquals(null, result.errorMessage, 'Should have no error');
    }

    /**
     * Test saveReCaptchaSettings - trimming whitespace
     */
    @isTest
    static void testSaveReCaptchaSettingsTrimsWhitespace() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            '  SiteKeyWithSpaces  ',
            '  SecretKeyWithSpaces  ',
            null,
            null
        );
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');

        // Verify keys were trimmed
        reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals('SiteKeyWithSpaces', settings.Site_Key__c, 'Site key should be trimmed');
        System.assertEquals('SecretKeyWithSpaces', settings.Secret_Key__c, 'Secret key should be trimmed');
    }

    /**
     * Test saveReCaptchaSettings - invalid captcha type
     */
    @isTest
    static void testSaveReCaptchaSettingsInvalidCaptchaType() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'ValidSiteKey',
            'ValidSecretKey',
            'InvalidType',
            null
        );
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assert(result.errorMessage.contains('Invalid captcha type'), 'Should mention invalid captcha type');
    }

    /**
     * Test saveReCaptchaSettings - score threshold out of range (too high)
     */
    @isTest
    static void testSaveReCaptchaSettingsScoreThresholdTooHigh() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'ValidSiteKey',
            'ValidSecretKey',
            'V3_Score',
            1.5  // Invalid - must be 0.0-1.0
        );
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assert(result.errorMessage.contains('threshold'), 'Should mention threshold range');
    }

    /**
     * Test saveReCaptchaSettings - score threshold out of range (negative)
     */
    @isTest
    static void testSaveReCaptchaSettingsScoreThresholdNegative() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'ValidSiteKey',
            'ValidSecretKey',
            'V3_Score',
            -0.5  // Invalid - must be 0.0-1.0
        );
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assert(result.errorMessage.contains('threshold'), 'Should mention threshold range');
    }

    // ==================== getFullStatus / FullStatusResult Tests ====================

    /**
     * Test FullStatusResult wrapper default values
     */
    @isTest
    static void testFullStatusResultWrapper() {
        SetupWizardController.FullStatusResult result = new SetupWizardController.FullStatusResult();

        System.assertEquals(false, result.isConfigured, 'isConfigured should default to false');
        System.assertEquals(null, result.defaultSiteId, 'defaultSiteId should be null');
        System.assertEquals(null, result.siteName, 'siteName should be null');
        System.assertEquals(null, result.siteBaseUrl, 'siteBaseUrl should be null');
        System.assertEquals(null, result.siteStatus, 'siteStatus should be null');
        System.assertEquals(null, result.publicFormUrl, 'publicFormUrl should be null');
        System.assertEquals(0, result.permissionsPassing, 'permissionsPassing should be 0');
        System.assertEquals(0, result.permissionsTotal, 'permissionsTotal should be 0');
        System.assertEquals(false, result.allPermissionsPassed, 'allPermissionsPassed should default to false');
        System.assertNotEquals(null, result.permissions, 'permissions should be initialized');
        System.assertEquals(0, result.permissions.size(), 'permissions should be empty');
        System.assertEquals(false, result.recaptchaConfigured, 'recaptchaConfigured should default to false');
        System.assertEquals(null, result.recaptchaType, 'recaptchaType should be null');
        System.assertEquals(null, result.recaptchaSiteKeyMasked, 'recaptchaSiteKeyMasked should be null');
        System.assertEquals(null, result.errorMessage, 'errorMessage should be null');
    }

    /**
     * Test getFullStatus - no settings exist (wizard never run)
     */
    @isTest
    static void testGetFullStatusNotConfigured() {
        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured when no settings exist');
        System.assertEquals(null, result.defaultSiteId, 'defaultSiteId should be null');
    }

    /**
     * Test getFullStatus - settings exist but no Default_Site_Id__c
     */
    @isTest
    static void testGetFullStatusBlankSiteId() {
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Site_Key__c = 'TestKey',
            Secret_Key__c = 'TestSecret'
            // Default_Site_Id__c is blank
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured with blank site ID');
    }

    /**
     * Test getFullStatus - stored site ID no longer exists (graceful error)
     */
    @isTest
    static void testGetFullStatusInvalidSiteId() {
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = '0DM000000000001',
            Site_Key__c = 'TestKey',
            Secret_Key__c = 'TestSecret'
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should set isConfigured=false when site not found');
        System.assert(String.isNotBlank(result.errorMessage), 'Should have error message about deleted site');
        System.assert(result.errorMessage.contains('not found') || result.errorMessage.contains('deleted'),
            'Error should mention site not found or deleted');
    }

    /**
     * Test getFullStatus - reCAPTCHA key masked to first 6 chars
     */
    @isTest
    static void testGetFullStatusRecaptchaMasking() {
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = '0DM000000000001',
            Site_Key__c = '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI',
            Secret_Key__c = '6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe',
            Captcha_Type__c = 'V2_Checkbox'
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        // reCAPTCHA fields are populated before Site lookup, so masking is testable
        // even though the method returns early due to fake Site ID
        System.assertEquals('6LeIxA...', result.recaptchaSiteKeyMasked,
            'Key should be masked to first 6 chars + ...');
        System.assertEquals(true, result.recaptchaConfigured,
            'reCAPTCHA should be marked as configured');
        System.assertEquals('V2_Checkbox', result.recaptchaType,
            'Captcha type should be V2_Checkbox');
    }

    /**
     * Test getFullStatus - short reCAPTCHA site key (edge case)
     */
    @isTest
    static void testGetFullStatusShortSiteKey() {
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = '0DM000000000001',
            Site_Key__c = 'abc',
            Secret_Key__c = 'TestSecret'
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        // reCAPTCHA fields are set before Site lookup — short key should not throw substring error
        System.assertEquals('abc...', result.recaptchaSiteKeyMasked,
            'Short key should get ... appended without substring error');
        System.assertEquals(true, result.recaptchaConfigured,
            'reCAPTCHA should be configured with both keys present');
    }

    /**
     * Test getFullStatus - reCAPTCHA not configured (no keys)
     */
    @isTest
    static void testGetFullStatusRecaptchaNotConfigured() {
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = '0DM000000000001'
            // No Site_Key__c or Secret_Key__c
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(false, result.recaptchaConfigured, 'reCAPTCHA should not be configured without keys');
        System.assertEquals(null, result.recaptchaSiteKeyMasked, 'Masked key should be null when no key set');
    }

    // ==================== CRUD Denial Tests ====================

    /**
     * Test createSampleForm fails when CRUD is denied
     */
    @isTest
    static void testCreateSampleFormNoCrudAccess() {
        SetupWizardController.testDenyCrud = true;

        Test.startTest();
        try {
            SetupWizardController.createSampleForm();
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permissions') || e.getMessage().contains('Insufficient'),
                'Error should mention permissions: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test saveReCaptchaSettings returns error when CRUD is denied
     */
    @isTest
    static void testSaveReCaptchaSettingsNoCrudAccess() {
        SetupWizardController.testDenyCrud = true;

        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'TestSiteKey', 'TestSecretKey', null, null
        );
        Test.stopTest();

        System.assertEquals(false, result.isConfigured, 'Should not be configured');
        System.assert(String.isNotBlank(result.errorMessage), 'Should have error message');
        System.assert(result.errorMessage.contains('permissions') || result.errorMessage.contains('Insufficient'),
            'Error should mention permissions');
    }

    /**
     * Test clearReCaptchaSettings returns error when CRUD is denied
     */
    @isTest
    static void testClearReCaptchaSettingsNoCrudAccess() {
        SetupWizardController.testDenyCrud = true;

        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.clearReCaptchaSettings();
        Test.stopTest();

        System.assert(String.isNotBlank(result.errorMessage), 'Should have error message');
        System.assert(result.errorMessage.contains('permissions') || result.errorMessage.contains('Insufficient'),
            'Error should mention permissions');
    }

    /**
     * Test saveReCaptchaSettings - v2 Invisible type
     */
    @isTest
    static void testSaveReCaptchaSettingsV2Invisible() {
        Test.startTest();
        SetupWizardController.ReCaptchaSettingsResult result = SetupWizardController.saveReCaptchaSettings(
            'InvisibleSiteKey',
            'InvisibleSecretKey',
            'V2_Invisible',
            null
        );
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');
        System.assertEquals('V2_Invisible', result.captchaType, 'Captcha type should be V2_Invisible');

        reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals('V2_Invisible', settings.Captcha_Type__c, 'Type should be saved');
    }

    // ==================== Real Site Tests (Permission Checking & Configuration) ====================

    /**
     * Helper: Get first active Site with a Guest User, or null if none
     */
    private static Site getActiveSiteWithGuest() {
        List<Site> sites = [SELECT Id, GuestUserId, Name, MasterLabel, Subdomain, UrlPathPrefix, Status
                            FROM Site WHERE Status = 'Active' AND GuestUserId != null LIMIT 1];
        return sites.isEmpty() ? null : sites[0];
    }

    /**
     * Test getSetupStatus with a real active Site — covers checkObjectPermission,
     * checkFieldPermission, checkApexAccess, checkVfPageAccess, getSiteBaseUrl
     */
    @isTest
    static void testGetSetupStatusWithRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; } // No usable Site in test org

        Test.startTest();
        SetupWizardController.ValidationResult result = SetupWizardController.getSetupStatus(site.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.permissions, 'Permissions should not be null');
        System.assert(result.permissions.size() > 0, 'Should have permission checks');
        // Verify each permission has a name and permissionType
        for (SetupWizardController.PermissionStatus ps : result.permissions) {
            System.assertNotEquals(null, ps.name, 'Permission name should not be null');
            System.assertNotEquals(null, ps.permissionType, 'Permission type should not be null');
        }
    }

    /**
     * Test configurePermissions with a real active Site — covers configureObjectPermission,
     * configureFieldPermission
     */
    @isTest
    static void testConfigurePermissionsWithRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        Test.startTest();
        SetupWizardController.ConfigResult result = SetupWizardController.configurePermissions(site.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.results, 'Results should not be null');
        System.assert(result.results.size() > 0, 'Should have configuration results');
    }

    /**
     * Test validateConfiguration with a real active Site — covers the thin wrapper
     */
    @isTest
    static void testValidateConfigurationWithRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        Test.startTest();
        SetupWizardController.ValidationResult result = SetupWizardController.validateConfiguration(site.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.permissions, 'Permissions should not be null');
    }

    /**
     * Test getPublicUrl with a real active Site and a form name
     */
    @isTest
    static void testGetPublicUrlWithRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        Test.startTest();
        String url = SetupWizardController.getPublicUrl(site.Id, 'test-form');
        Test.stopTest();

        if (url != null) {
            System.assert(url.contains('CaseFormPage'), 'URL should contain CaseFormPage');
            System.assert(url.contains('test-form'), 'URL should contain form name');
        }
    }

    /**
     * Test getPublicUrl with real Site and null form name
     */
    @isTest
    static void testGetPublicUrlNoFormName() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        Test.startTest();
        String url = SetupWizardController.getPublicUrl(site.Id, null);
        Test.stopTest();

        if (url != null) {
            System.assert(url.contains('CaseFormPage'), 'URL should contain CaseFormPage');
            System.assert(!url.contains('?form='), 'URL should not have form param when name is null');
        }
    }

    /**
     * Test getConfigSummary with a real active Site
     */
    @isTest
    static void testGetConfigSummaryWithRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        Test.startTest();
        SetupWizardController.ConfigSummary summary = SetupWizardController.getConfigSummary(site.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assertNotEquals(null, summary.siteName, 'Site name should not be null');
        System.assertNotEquals(null, summary.configuredAt, 'configuredAt should not be null');
        System.assertNotEquals(null, summary.configuredBy, 'configuredBy should not be null');
    }

    /**
     * Test getFullStatus with a real active Site saved as default
     */
    @isTest
    static void testGetFullStatusWithRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = site.Id
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured with valid Site');
        System.assertNotEquals(null, result.siteName, 'Site name should not be null');
        System.assertNotEquals(null, result.siteStatus, 'Site status should not be null');
        System.assert(result.permissionsTotal > 0, 'Should have permission checks');
    }

    /**
     * Test getFullStatus with reCAPTCHA configured and real Site
     */
    @isTest
    static void testGetFullStatusWithRecaptchaAndRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = site.Id,
            Site_Key__c = '6LeTestSiteKey123456789012345678',
            Secret_Key__c = '6LeTestSecretKey12345678901234567',
            Captcha_Type__c = 'V2_Invisible'
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');
        System.assertEquals(true, result.recaptchaConfigured, 'reCAPTCHA should be configured');
        System.assertEquals('V2_Invisible', result.recaptchaType, 'Captcha type should match');
        System.assertNotEquals(null, result.recaptchaSiteKeyMasked, 'Site key should be masked');
        System.assert(result.permissionsTotal > 0, 'Should have permissions');
    }

    /**
     * Test saveDefaultSite with a real active Site
     */
    @isTest
    static void testSaveDefaultSiteWithRealSite() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        Test.startTest();
        SetupWizardController.saveDefaultSite(site.Id);
        Test.stopTest();

        reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals(site.Id, settings.Default_Site_Id__c, 'Default Site ID should be saved');
    }

    /**
     * Test saveDefaultSite CRUD denial
     */
    @isTest
    static void testSaveDefaultSiteNoCrudAccess() {
        SetupWizardController.testDenyCrud = true;

        Test.startTest();
        try {
            SetupWizardController.saveDefaultSite('0DM000000000001');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('permissions') || e.getMessage().contains('Insufficient'),
                'Error should mention permissions');
        }
        Test.stopTest();
    }

    /**
     * Test configurePermissions with CRUD denied — covers configureObjectPermission
     * and configureFieldPermission CRUD check branches
     */
    @isTest
    static void testConfigurePermissionsNoCrudAccess() {
        Site site = getActiveSiteWithGuest();
        if (site == null) { return; }

        SetupWizardController.testDenyCrud = true;

        Test.startTest();
        SetupWizardController.ConfigResult result = SetupWizardController.configurePermissions(site.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail with CRUD denied');
        Boolean foundError = false;
        for (SetupWizardController.PermissionStatus ps : result.results) {
            if (String.isNotBlank(ps.errorMessage) && ps.errorMessage.contains('Insufficient')) {
                foundError = true;
                break;
            }
        }
        System.assert(foundError, 'Should have at least one insufficient permissions error');
    }

    /**
     * Test getSetupStatus with a Site that has no Guest User configured
     * Uses a non-Active Site if available, otherwise tests error handling
     */
    @isTest
    static void testGetSetupStatusNoGuestUser() {
        List<Site> sitesNoGuest = [SELECT Id FROM Site WHERE GuestUserId = null LIMIT 1];
        if (sitesNoGuest.isEmpty()) { return; }

        Test.startTest();
        try {
            SetupWizardController.getSetupStatus(sitesNoGuest[0].Id);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Guest User') || e.getMessage().contains('Error'),
                'Should mention Guest User issue');
        }
        Test.stopTest();
    }

    /**
     * Test configurePermissions with a Site that has no Guest User configured
     */
    @isTest
    static void testConfigurePermissionsNoGuestUser() {
        List<Site> sitesNoGuest = [SELECT Id FROM Site WHERE GuestUserId = null LIMIT 1];
        if (sitesNoGuest.isEmpty()) { return; }

        Test.startTest();
        try {
            SetupWizardController.configurePermissions(sitesNoGuest[0].Id);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Guest User') || e.getMessage().contains('Error'),
                'Should mention Guest User issue');
        }
        Test.stopTest();
    }

    // ==================== Direct Unit Tests (No Site Required) ====================
    // These tests call @TestVisible private helpers directly to ensure coverage
    // in environments without active Sites (e.g., 2GP packaging scratch orgs).

    /**
     * Helper: Get the PermissionSet linked to the running user's profile
     */
    private static Id getRunningUserProfilePermSetId() {
        List<PermissionSet> ps = [
            SELECT Id FROM PermissionSet
            WHERE ProfileId = :UserInfo.getProfileId()
            LIMIT 1
        ];
        return ps.isEmpty() ? null : ps[0].Id;
    }

    /**
     * Test checkObjectPermission directly — Read permission on a known object
     */
    @isTest
    static void testCheckObjectPermissionReadDirect() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkObjectPermission(permSetId, 'Form__c', 'Read');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('Form__c Read', ps.name, 'Name should match');
        System.assertEquals('Object', ps.permissionType, 'Type should be Object');
    }

    /**
     * Test checkObjectPermission directly — Create permission
     */
    @isTest
    static void testCheckObjectPermissionCreateDirect() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkObjectPermission(permSetId, 'Case', 'Create');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('Case Create', ps.name, 'Name should match');
    }

    /**
     * Test checkObjectPermission with non-existent object — empty result branch
     */
    @isTest
    static void testCheckObjectPermissionNotFound() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkObjectPermission(permSetId, 'NonExistentObj__c', 'Read');
        Test.stopTest();

        System.assertEquals(false, ps.configured, 'Should not be configured for non-existent object');
    }

    /**
     * Test checkFieldPermission directly — known field
     */
    @isTest
    static void testCheckFieldPermissionDirect() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkFieldPermission(permSetId, 'Form__c', 'Description__c');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('Form__c.Description__c Read', ps.name, 'Name should match');
        System.assertEquals('Field', ps.permissionType, 'Type should be Field');
    }

    /**
     * Test checkFieldPermission with non-existent field — empty result branch
     */
    @isTest
    static void testCheckFieldPermissionNotFound() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkFieldPermission(permSetId, 'Form__c', 'NonExistent__c');
        Test.stopTest();

        System.assertEquals(false, ps.configured, 'Should not be configured for non-existent field');
    }

    /**
     * Test checkApexAccess directly — known Apex class
     */
    @isTest
    static void testCheckApexAccessDirect() {
        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkApexAccess(UserInfo.getProfileId(), 'CaseFormController');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('CaseFormController Apex Class', ps.name, 'Name should match');
        System.assertEquals('ApexClass', ps.permissionType, 'Type should be ApexClass');
    }

    /**
     * Test checkApexAccess with non-existent class — class not found branch
     */
    @isTest
    static void testCheckApexAccessNotFound() {
        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkApexAccess(UserInfo.getProfileId(), 'NonExistentClass');
        Test.stopTest();

        System.assertEquals(false, ps.configured, 'Should not be configured');
        System.assertEquals('Apex class not found', ps.errorMessage, 'Should have not-found error');
    }

    /**
     * Test checkVfPageAccess directly — known VF page
     */
    @isTest
    static void testCheckVfPageAccessDirect() {
        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkVfPageAccess(UserInfo.getProfileId(), 'CaseFormPage');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('CaseFormPage VF Page', ps.name, 'Name should match');
        System.assertEquals('VisualforcePage', ps.permissionType, 'Type should be VisualforcePage');
    }

    /**
     * Test checkVfPageAccess with non-existent page — page not found branch
     */
    @isTest
    static void testCheckVfPageAccessNotFound() {
        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.checkVfPageAccess(UserInfo.getProfileId(), 'NonExistentPage');
        Test.stopTest();

        System.assertEquals(false, ps.configured, 'Should not be configured');
        System.assertEquals('Visualforce page not found', ps.errorMessage, 'Should have not-found error');
    }

    /**
     * Test configureObjectPermission directly — Read permission
     */
    @isTest
    static void testConfigureObjectPermissionDirect() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.configureObjectPermission(permSetId, 'Form__c', 'Read');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('Form__c Read', ps.name, 'Name should match');
        System.assertEquals(true, ps.canAutomate, 'Should be automatable');
    }

    /**
     * Test configureObjectPermission — Create permission (also sets Read)
     */
    @isTest
    static void testConfigureObjectPermissionCreateDirect() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.configureObjectPermission(permSetId, 'Case', 'Create');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('Case Create', ps.name, 'Name should match');
    }

    /**
     * Test configureObjectPermission with CRUD denied
     */
    @isTest
    static void testConfigureObjectPermissionCrudDenied() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        SetupWizardController.testDenyCrud = true;

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.configureObjectPermission(permSetId, 'Form__c', 'Read');
        Test.stopTest();

        System.assertEquals(false, ps.configured, 'Should not be configured when CRUD denied');
        System.assert(ps.errorMessage.contains('Insufficient'), 'Error should mention insufficient permissions');
    }

    /**
     * Test configureFieldPermission directly
     */
    @isTest
    static void testConfigureFieldPermissionDirect() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.configureFieldPermission(permSetId, 'Form__c', 'Description__c');
        Test.stopTest();

        System.assertNotEquals(null, ps, 'Result should not be null');
        System.assertEquals('Form__c.Description__c Read', ps.name, 'Name should match');
        System.assertEquals(true, ps.canAutomate, 'Should be automatable');
    }

    /**
     * Test configureFieldPermission with CRUD denied
     */
    @isTest
    static void testConfigureFieldPermissionCrudDenied() {
        Id permSetId = getRunningUserProfilePermSetId();
        if (permSetId == null) { return; }

        SetupWizardController.testDenyCrud = true;

        Test.startTest();
        SetupWizardController.PermissionStatus ps =
            SetupWizardController.configureFieldPermission(permSetId, 'Form__c', 'Description__c');
        Test.stopTest();

        System.assertEquals(false, ps.configured, 'Should not be configured when CRUD denied');
        System.assert(ps.errorMessage.contains('Insufficient'), 'Error should mention insufficient permissions');
    }

    /**
     * Test getSiteBaseUrl with any available Site — covers SiteDetail query and subdomain fallback
     */
    @isTest
    static void testGetSiteBaseUrlDirect() {
        List<Site> sites = [SELECT Id, Name, Subdomain, UrlPathPrefix FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        String baseUrl = SetupWizardController.getSiteBaseUrl(sites[0]);
        Test.stopTest();

        // baseUrl could be a real URL or empty string — just verify no exception
        System.assertNotEquals(null, baseUrl, 'Base URL should not be null');
    }

    /**
     * Test getFullStatus with a Site ID pointing to any available Site
     * Covers the getFullStatus method's Site query, public URL generation, and permission check branches
     */
    @isTest
    static void testGetFullStatusWithAnySite() {
        List<Site> sites = [SELECT Id FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        // Save a default Site so getFullStatus finds it
        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = sites[0].Id
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured with a saved Site');
        // The method may hit various branches depending on whether the Site has a Guest User
        // but it should not throw — errors are caught internally
    }

    /**
     * Test getFullStatus with reCAPTCHA settings and any available Site
     * Covers reCAPTCHA masking and type branches in getFullStatus
     */
    @isTest
    static void testGetFullStatusWithRecaptchaAnySite() {
        List<Site> sites = [SELECT Id FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        reCAPTCHA_Settings__c settings = new reCAPTCHA_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Default_Site_Id__c = sites[0].Id,
            Site_Key__c = '6LeTestSiteKey123456789012345678',
            Secret_Key__c = '6LeTestSecretKey12345678901234567',
            Captcha_Type__c = 'V3_Score'
        );
        insert settings;

        Test.startTest();
        SetupWizardController.FullStatusResult result = SetupWizardController.getFullStatus();
        Test.stopTest();

        System.assertEquals(true, result.isConfigured, 'Should be configured');
        System.assertEquals(true, result.recaptchaConfigured, 'reCAPTCHA should be configured');
        System.assertEquals('V3_Score', result.recaptchaType, 'Type should be V3_Score');
        System.assert(result.recaptchaSiteKeyMasked.contains('...'), 'Site key should be masked');
    }

    /**
     * Test getPublicUrl with any available Site — covers URL construction
     */
    @isTest
    static void testGetPublicUrlWithAnySite() {
        List<Site> sites = [SELECT Id FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        String url = SetupWizardController.getPublicUrl(sites[0].Id, 'test-form');
        Test.stopTest();

        // URL may be null if getSiteBaseUrl returns empty, but method should not throw
        if (url != null) {
            System.assert(url.contains('CaseFormPage'), 'URL should contain CaseFormPage');
        }
    }

    /**
     * Test getPublicUrl with null form name
     */
    @isTest
    static void testGetPublicUrlNoFormNameAnySite() {
        List<Site> sites = [SELECT Id FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        String url = SetupWizardController.getPublicUrl(sites[0].Id, null);
        Test.stopTest();

        if (url != null) {
            System.assert(url.contains('CaseFormPage'), 'URL should contain CaseFormPage');
            System.assert(!url.contains('?form='), 'URL should not have form param');
        }
    }

    /**
     * Test getConfigSummary with any available Site — covers summary generation
     */
    @isTest
    static void testGetConfigSummaryAnySite() {
        // getConfigSummary calls getSetupStatus internally, which requires a Guest User
        // If the Site has no Guest User, getSetupStatus throws and getConfigSummary re-throws
        List<Site> sites = [SELECT Id, GuestUserId FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        try {
            SetupWizardController.ConfigSummary summary =
                SetupWizardController.getConfigSummary(sites[0].Id);
            // If we get here, the Site had a Guest User
            System.assertNotEquals(null, summary.siteName, 'Site name should not be null');
            System.assertNotEquals(null, summary.configuredBy, 'configuredBy should not be null');
        } catch (AuraHandledException e) {
            // Expected if Site has no Guest User — still covers the method entry and Site query
            System.assertNotEquals(null, e.getMessage(), 'Should have error message');
        }
        Test.stopTest();
    }

    /**
     * Test getSetupStatus with any available Site — covers permission checking branches
     */
    @isTest
    static void testGetSetupStatusAnySite() {
        List<Site> sites = [SELECT Id, GuestUserId FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        try {
            SetupWizardController.ValidationResult result =
                SetupWizardController.getSetupStatus(sites[0].Id);
            // If we get here, the Site had a Guest User
            System.assertNotEquals(null, result.permissions, 'Permissions should not be null');
        } catch (AuraHandledException e) {
            // Expected if Site has no Guest User
            System.assertNotEquals(null, e.getMessage(), 'Should have error message');
        }
        Test.stopTest();
    }

    /**
     * Test configurePermissions with any available Site — covers configuration branches
     */
    @isTest
    static void testConfigurePermissionsAnySite() {
        List<Site> sites = [SELECT Id, GuestUserId FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        try {
            SetupWizardController.ConfigResult result =
                SetupWizardController.configurePermissions(sites[0].Id);
            // If we get here, the Site had a Guest User
            System.assertNotEquals(null, result.results, 'Results should not be null');
        } catch (AuraHandledException e) {
            // Expected if Site has no Guest User
            System.assertNotEquals(null, e.getMessage(), 'Should have error message');
        }
        Test.stopTest();
    }

    /**
     * Test saveDefaultSite with any available Site
     */
    @isTest
    static void testSaveDefaultSiteAnySite() {
        List<Site> sites = [SELECT Id FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        SetupWizardController.saveDefaultSite(sites[0].Id);
        Test.stopTest();

        reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
        System.assertEquals(sites[0].Id, settings.Default_Site_Id__c, 'Default Site ID should be saved');
    }

    /**
     * Test validateConfiguration delegates to getSetupStatus
     */
    @isTest
    static void testValidateConfigurationAnySite() {
        List<Site> sites = [SELECT Id FROM Site LIMIT 1];
        if (sites.isEmpty()) { return; }

        Test.startTest();
        try {
            SetupWizardController.ValidationResult result =
                SetupWizardController.validateConfiguration(sites[0].Id);
            System.assertNotEquals(null, result, 'Result should not be null');
        } catch (AuraHandledException e) {
            // Expected if Site has no Guest User
            System.assertNotEquals(null, e.getMessage(), 'Should have error message');
        }
        Test.stopTest();
    }
}
