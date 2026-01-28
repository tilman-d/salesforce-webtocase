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
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User standardUser = new User(
            ProfileId = standardProfile.Id,
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
}
