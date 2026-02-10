/**
 * SetupWizardController - Controller for the Post-Install Setup Wizard
 * Handles site detection, permission configuration, and validation for Guest User access
 *
 * Security: Uses 'with sharing' - Admin-only controller
 */
public with sharing class SetupWizardController {

    // Objects that need permissions configured
    private static final List<String> REQUIRED_OBJECT_READ = new List<String>{'Form__c', 'Form_Field__c', 'Error_Log__c'};
    // Note: 'without sharing' bypasses sharing rules (record-level security) but NOT CRUD/FLS
    // describe checks. ContentVersion and ContentDocumentLink are standard objects whose CRUD
    // permissions are typically pre-granted on Site Guest User profiles by the platform.
    // Runtime CRUD checks in CaseFormController will validate and fail with a clear error
    // if these permissions are missing.
    private static final List<String> REQUIRED_OBJECT_CREATE = new List<String>{'Case', 'Error_Log__c'};

    // Fields that need read permissions
    private static final Map<String, List<String>> REQUIRED_FIELD_READ = new Map<String, List<String>>{
        'Form__c' => new List<String>{'Description__c', 'Enable_File_Upload__c', 'Max_File_Size_MB__c', 'Success_Message__c'},
        'Form_Field__c' => new List<String>{'Required__c'},
        'Error_Log__c' => new List<String>{'Error_Message__c', 'Form_Id__c', 'Timestamp__c'}
    };

    // Apex classes that need access
    private static final List<String> REQUIRED_APEX_CLASSES = new List<String>{'CaseFormController', 'ErrorLogger'};

    // VF pages that need access
    private static final List<String> REQUIRED_VF_PAGES = new List<String>{'CaseFormPage'};

    // Test-visible flag to simulate CRUD denial in tests
    @TestVisible private static Boolean testDenyCrud = false;

    /**
     * Wrapper for precondition check results
     */
    public class PreconditionResult {
        @AuraEnabled public Boolean allPassed;
        @AuraEnabled public Boolean myDomainDeployed;
        @AuraEnabled public Boolean hasAdminPermissions;
        @AuraEnabled public Boolean sitesEnabled;
        @AuraEnabled public String errorMessage;

        public PreconditionResult() {
            this.allPassed = false;
            this.myDomainDeployed = false;
            this.hasAdminPermissions = false;
            this.sitesEnabled = false;
        }
    }

    /**
     * Wrapper for Site info
     */
    public class SiteInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String masterLabel;
        @AuraEnabled public String guestUserId;
        @AuraEnabled public String subdomain;
        @AuraEnabled public String urlPathPrefix;
        @AuraEnabled public String status;
        @AuraEnabled public String baseUrl;

        public SiteInfo() {}

        public SiteInfo(Site s) {
            this.id = s.Id;
            this.name = s.Name;
            this.masterLabel = s.MasterLabel;
            this.guestUserId = s.GuestUserId;
            this.subdomain = s.Subdomain;
            this.urlPathPrefix = s.UrlPathPrefix;
            this.status = s.Status;
        }
    }

    /**
     * Wrapper for permission status
     */
    public class PermissionStatus {
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean configured;
        @AuraEnabled public Boolean canAutomate;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String permissionType;

        public PermissionStatus() {
            this.configured = false;
            this.canAutomate = false;
        }

        public PermissionStatus(String name, String description, Boolean configured, Boolean canAutomate, String permissionType) {
            this.name = name;
            this.description = description;
            this.configured = configured;
            this.canAutomate = canAutomate;
            this.permissionType = permissionType;
        }
    }

    /**
     * Wrapper for validation result
     */
    public class ValidationResult {
        @AuraEnabled public Boolean allPassed;
        @AuraEnabled public List<PermissionStatus> permissions;
        @AuraEnabled public String publicUrl;

        public ValidationResult() {
            this.allPassed = false;
            this.permissions = new List<PermissionStatus>();
        }
    }

    /**
     * Wrapper for configuration result (from async operation)
     */
    public class ConfigResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public List<PermissionStatus> results;
        @AuraEnabled public String errorMessage;

        public ConfigResult() {
            this.success = false;
            this.results = new List<PermissionStatus>();
        }
    }

    /**
     * Wrapper for config summary (diagnostics export)
     */
    public class ConfigSummary {
        @AuraEnabled public String siteName;
        @AuraEnabled public String siteUrl;
        @AuraEnabled public List<String> permissionsApplied;
        @AuraEnabled public String configuredAt;
        @AuraEnabled public String configuredBy;

        public ConfigSummary() {
            this.permissionsApplied = new List<String>();
        }
    }

    /**
     * Wrapper for reCAPTCHA settings result
     */
    public class ReCaptchaSettingsResult {
        @AuraEnabled public Boolean isConfigured;
        @AuraEnabled public String siteKey;
        @AuraEnabled public Boolean hasSecretKey;
        @AuraEnabled public String captchaType;
        @AuraEnabled public Decimal scoreThreshold;
        @AuraEnabled public String errorMessage;

        public ReCaptchaSettingsResult() {
            this.isConfigured = false;
            this.hasSecretKey = false;
            this.captchaType = 'V2_Checkbox';
            this.scoreThreshold = 0.3;
        }
    }

    /**
     * Wrapper for full configuration status (used by setupStatus dashboard)
     */
    public class FullStatusResult {
        @AuraEnabled public Boolean isConfigured;
        @AuraEnabled public String defaultSiteId;
        @AuraEnabled public String siteName;
        @AuraEnabled public String siteBaseUrl;
        @AuraEnabled public String siteStatus;
        @AuraEnabled public String publicFormUrl;
        @AuraEnabled public Integer permissionsPassing;
        @AuraEnabled public Integer permissionsTotal;
        @AuraEnabled public Boolean allPermissionsPassed;
        @AuraEnabled public List<PermissionStatus> permissions;
        @AuraEnabled public Boolean recaptchaConfigured;
        @AuraEnabled public String recaptchaType;
        @AuraEnabled public String recaptchaSiteKeyMasked;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String permissionsError;
        @AuraEnabled public String publicUrlError;

        public FullStatusResult() {
            this.isConfigured = false;
            this.permissionsPassing = 0;
            this.permissionsTotal = 0;
            this.allPermissionsPassed = false;
            this.permissions = new List<PermissionStatus>();
            this.recaptchaConfigured = false;
        }
    }

    /**
     * Get full configuration status for the status dashboard
     * Returns site info, permission summary, and reCAPTCHA status in a single call.
     * NOT cacheable — imperative call allows refresh after wizard completes.
     */
    @AuraEnabled
    public static FullStatusResult getFullStatus() {
        FullStatusResult result = new FullStatusResult();

        try {
            // 1. Read org-level settings
            reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();

            if (settings == null || settings.Id == null || String.isBlank(settings.Default_Site_Id__c)) {
                result.isConfigured = false;
                return result;
            }

            result.isConfigured = true;
            result.defaultSiteId = settings.Default_Site_Id__c;

            // 2. Populate reCAPTCHA fields
            result.recaptchaConfigured = String.isNotBlank(settings.Site_Key__c) &&
                                          String.isNotBlank(settings.Secret_Key__c);
            result.recaptchaType = String.isNotBlank(settings.Captcha_Type__c) ?
                                   settings.Captcha_Type__c : 'V2_Checkbox';
            if (String.isNotBlank(settings.Site_Key__c)) {
                String siteKey = settings.Site_Key__c;
                result.recaptchaSiteKeyMasked = siteKey.length() > 6 ?
                    siteKey.substring(0, 6) + '...' : siteKey + '...';
            }

            // 3. Query Site record
            try {
                Site site = [SELECT Id, Name, MasterLabel, Status, Subdomain, UrlPathPrefix
                             FROM Site WHERE Id = :settings.Default_Site_Id__c LIMIT 1];
                result.siteName = site.MasterLabel;
                result.siteStatus = site.Status;
                result.siteBaseUrl = getSiteBaseUrl(site);
            } catch (QueryException e) {
                result.isConfigured = false;
                result.errorMessage = 'The configured Site was not found. It may have been deleted. Please re-run the wizard.';
                return result;
            } catch (Exception e) {
                result.isConfigured = false;
                result.errorMessage = 'Error loading Site details: ' + e.getMessage();
                ErrorLogger.logException(e, null);
                return result;
            }

            // 4. Get canonical public URL
            try {
                result.publicFormUrl = getPublicUrl(settings.Default_Site_Id__c, null);
            } catch (Exception e) {
                result.publicUrlError = 'Unable to determine public URL: ' + e.getMessage();
                ErrorLogger.logException(e, null);
            }

            // 5. Check permissions
            try {
                ValidationResult validation = getSetupStatus(settings.Default_Site_Id__c);
                result.permissions = validation.permissions;
                result.allPermissionsPassed = validation.allPassed;
                Integer passing = 0;
                for (PermissionStatus ps : validation.permissions) {
                    if (ps.configured) {
                        passing++;
                    }
                }
                result.permissionsPassing = passing;
                result.permissionsTotal = validation.permissions.size();
            } catch (Exception e) {
                result.permissionsError = 'Unable to check permissions: ' + e.getMessage();
                ErrorLogger.logException(e, null);
            }

        } catch (Exception e) {
            result.errorMessage = 'Error loading configuration status: ' + e.getMessage();
            ErrorLogger.logException(e, null);
        }

        return result;
    }

    /**
     * Helper method to create AuraHandledException with proper message
     */
    private static AuraHandledException createException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * Check preconditions for setup wizard
     * - My Domain deployed
     * - Admin permissions (Modify All Data or Customize Application)
     * - Sites feature enabled
     */
    @AuraEnabled
    public static PreconditionResult checkPreconditions() {
        PreconditionResult result = new PreconditionResult();

        try {
            // Check My Domain - if we can get the org's domain, it's deployed
            result.myDomainDeployed = checkMyDomain();

            // Check admin permissions
            result.hasAdminPermissions = checkAdminPermissions();

            // Check if Sites feature is enabled
            result.sitesEnabled = checkSitesEnabled();

            // All must pass
            result.allPassed = result.myDomainDeployed && result.hasAdminPermissions && result.sitesEnabled;

            if (!result.allPassed) {
                List<String> issues = new List<String>();
                if (!result.myDomainDeployed) issues.add('My Domain is not deployed');
                if (!result.hasAdminPermissions) issues.add('Missing Modify All Data or Customize Application permission');
                if (!result.sitesEnabled) issues.add('Sites feature is not enabled');
                result.errorMessage = String.join(issues, '; ');
            }
        } catch (Exception e) {
            result.errorMessage = 'Error checking preconditions: ' + e.getMessage();
            ErrorLogger.logException(e, null);
        }

        return result;
    }

    /**
     * Check if My Domain is deployed
     */
    private static Boolean checkMyDomain() {
        try {
            // Get the org's domain - if it exists and is not empty, My Domain is deployed
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            return String.isNotBlank(baseUrl) && !baseUrl.contains('salesforce.com/id/');
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Check if current user has admin permissions
     */
    private static Boolean checkAdminPermissions() {
        // Check for Modify All Data or Customize Application
        return FeatureManagement.checkPermission('ModifyAllData') ||
               FeatureManagement.checkPermission('CustomizeApplication') ||
               [SELECT COUNT() FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSet.PermissionsModifyAllData = true] > 0;
    }

    /**
     * Check if Sites feature is enabled in the org
     */
    private static Boolean checkSitesEnabled() {
        try {
            // If we can query the Site object, Sites is enabled
            Integer siteCount = [SELECT COUNT() FROM Site];
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Get list of active Sites in the org
     */
    @AuraEnabled
    public static List<SiteInfo> getActiveSites() {
        List<SiteInfo> sites = new List<SiteInfo>();

        try {
            for (Site s : [
                SELECT Id, Name, MasterLabel, GuestUserId, Subdomain, UrlPathPrefix, Status
                FROM Site
                WHERE Status = 'Active'
                ORDER BY MasterLabel ASC
            ]) {
                SiteInfo info = new SiteInfo(s);
                // Derive base URL dynamically
                info.baseUrl = getSiteBaseUrl(s);
                sites.add(info);
            }
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            throw createException('Error retrieving sites: ' + e.getMessage());
        }

        return sites;
    }

    /**
     * Dynamically derive the Site's base URL
     */
    private static String getSiteBaseUrl(Site s) {
        try {
            // Use SiteDetail to get the secure URL
            List<SiteDetail> details = [
                SELECT SecureUrl
                FROM SiteDetail
                WHERE DurableId = :s.Id
            ];
            if (!details.isEmpty() && String.isNotBlank(details[0].SecureUrl)) {
                return details[0].SecureUrl;
            }

            // Fallback: construct from subdomain
            String orgDomain = URL.getOrgDomainUrl().toExternalForm();
            if (String.isNotBlank(s.Subdomain)) {
                // Enhanced domain format: https://subdomain.my.site.com
                return 'https://' + s.Subdomain + '.my.site.com';
            }

            return orgDomain;
        } catch (Exception e) {
            return '';
        }
    }

    /**
     * Get current setup status for a Site's Guest User
     */
    @AuraEnabled
    public static ValidationResult getSetupStatus(String siteId) {
        if (String.isBlank(siteId)) {
            throw createException('Site ID is required');
        }

        ValidationResult result = new ValidationResult();

        try {
            // Get the Site and Guest User info
            Site site = [SELECT Id, GuestUserId, Name FROM Site WHERE Id = :siteId LIMIT 1];
            if (site.GuestUserId == null) {
                throw createException('Site does not have a Guest User configured');
            }

            // Get the Guest User's Profile
            User guestUser = [SELECT ProfileId FROM User WHERE Id = :site.GuestUserId LIMIT 1];

            // Get the PermissionSet linked to this Profile
            List<PermissionSet> profilePS = [
                SELECT Id FROM PermissionSet
                WHERE ProfileId = :guestUser.ProfileId
                LIMIT 1
            ];

            if (profilePS.isEmpty()) {
                throw createException('Could not find Permission Set for Guest User Profile');
            }

            Id permSetId = profilePS[0].Id;

            // Check object permissions - Read
            for (String objName : REQUIRED_OBJECT_READ) {
                PermissionStatus ps = checkObjectPermission(permSetId, objName, 'Read');
                ps.canAutomate = true;
                result.permissions.add(ps);
            }

            // Check object permissions - Create (automatable)
            for (String objName : REQUIRED_OBJECT_CREATE) {
                PermissionStatus ps = checkObjectPermission(permSetId, objName, 'Create');
                ps.canAutomate = true;
                result.permissions.add(ps);
            }

            // Check field permissions
            for (String objName : REQUIRED_FIELD_READ.keySet()) {
                for (String fieldName : REQUIRED_FIELD_READ.get(objName)) {
                    PermissionStatus ps = checkFieldPermission(permSetId, objName, fieldName);
                    ps.canAutomate = true;
                    result.permissions.add(ps);
                }
            }

            // Check Apex class access (manual only)
            for (String className : REQUIRED_APEX_CLASSES) {
                PermissionStatus ps = checkApexAccess(guestUser.ProfileId, className);
                ps.canAutomate = false;
                result.permissions.add(ps);
            }

            // Check VF page access (manual only)
            for (String pageName : REQUIRED_VF_PAGES) {
                PermissionStatus ps = checkVfPageAccess(guestUser.ProfileId, pageName);
                ps.canAutomate = false;
                result.permissions.add(ps);
            }

            // Determine if all passed
            result.allPassed = true;
            for (PermissionStatus ps : result.permissions) {
                if (!ps.configured) {
                    result.allPassed = false;
                    break;
                }
            }

            // Get public URL
            result.publicUrl = getPublicUrl(siteId, null);

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            throw createException('Error checking setup status: ' + e.getMessage());
        }

        return result;
    }

    /**
     * Check object permission for a permission set
     * Note: ObjectPermissions is a setup entity — CRUD checks on setup objects are not
     * enforced since this method runs in admin-only (with sharing) context.
     */
    private static PermissionStatus checkObjectPermission(Id permSetId, String objectName, String permType) {
        PermissionStatus ps = new PermissionStatus();
        ps.name = objectName + ' ' + permType;
        ps.permissionType = 'Object';

        try {
            List<ObjectPermissions> perms = [
                SELECT Id, PermissionsRead, PermissionsCreate
                FROM ObjectPermissions
                WHERE ParentId = :permSetId AND SobjectType = :objectName
                LIMIT 1
            ];

            if (!perms.isEmpty()) {
                if (permType == 'Read') {
                    ps.configured = perms[0].PermissionsRead;
                    ps.description = 'Read access to ' + objectName;
                } else if (permType == 'Create') {
                    ps.configured = perms[0].PermissionsCreate;
                    ps.description = 'Create access to ' + objectName;
                }
            } else {
                ps.configured = false;
                ps.description = permType + ' access to ' + objectName;
            }
        } catch (Exception e) {
            ps.configured = false;
            ps.errorMessage = e.getMessage();
        }

        return ps;
    }

    /**
     * Check field permission for a permission set
     */
    private static PermissionStatus checkFieldPermission(Id permSetId, String objectName, String fieldName) {
        PermissionStatus ps = new PermissionStatus();
        ps.name = objectName + '.' + fieldName + ' Read';
        ps.description = 'Read access to ' + objectName + '.' + fieldName;
        ps.permissionType = 'Field';

        try {
            String fieldKey = objectName + '.' + fieldName;
            List<FieldPermissions> perms = [
                SELECT Id, PermissionsRead
                FROM FieldPermissions
                WHERE ParentId = :permSetId AND Field = :fieldKey
                LIMIT 1
            ];

            ps.configured = !perms.isEmpty() && perms[0].PermissionsRead;
        } catch (Exception e) {
            ps.configured = false;
            ps.errorMessage = e.getMessage();
        }

        return ps;
    }

    /**
     * Check Apex class access for a profile
     */
    private static PermissionStatus checkApexAccess(Id profileId, String className) {
        PermissionStatus ps = new PermissionStatus();
        ps.name = className + ' Apex Class';
        ps.description = 'Execute access to ' + className + ' Apex class';
        ps.permissionType = 'ApexClass';

        try {
            // Get the ApexClass Id
            List<ApexClass> classes = [SELECT Id FROM ApexClass WHERE Name = :className LIMIT 1];
            if (classes.isEmpty()) {
                ps.configured = false;
                ps.errorMessage = 'Apex class not found';
                return ps;
            }

            // Check SetupEntityAccess for the Profile's PermissionSet
            List<PermissionSet> profilePS = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId LIMIT 1];
            if (profilePS.isEmpty()) {
                ps.configured = false;
                return ps;
            }

            List<SetupEntityAccess> access = [
                SELECT Id FROM SetupEntityAccess
                WHERE ParentId = :profilePS[0].Id AND SetupEntityId = :classes[0].Id
                LIMIT 1
            ];

            ps.configured = !access.isEmpty();
        } catch (Exception e) {
            ps.configured = false;
            ps.errorMessage = e.getMessage();
        }

        return ps;
    }

    /**
     * Check VF page access for a profile
     */
    private static PermissionStatus checkVfPageAccess(Id profileId, String pageName) {
        PermissionStatus ps = new PermissionStatus();
        ps.name = pageName + ' VF Page';
        ps.description = 'Access to ' + pageName + ' Visualforce page';
        ps.permissionType = 'VisualforcePage';

        try {
            // Get the ApexPage Id
            List<ApexPage> pages = [SELECT Id FROM ApexPage WHERE Name = :pageName LIMIT 1];
            if (pages.isEmpty()) {
                ps.configured = false;
                ps.errorMessage = 'Visualforce page not found';
                return ps;
            }

            // Check SetupEntityAccess for the Profile's PermissionSet
            List<PermissionSet> profilePS = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId LIMIT 1];
            if (profilePS.isEmpty()) {
                ps.configured = false;
                return ps;
            }

            List<SetupEntityAccess> access = [
                SELECT Id FROM SetupEntityAccess
                WHERE ParentId = :profilePS[0].Id AND SetupEntityId = :pages[0].Id
                LIMIT 1
            ];

            ps.configured = !access.isEmpty();
        } catch (Exception e) {
            ps.configured = false;
            ps.errorMessage = e.getMessage();
        }

        return ps;
    }

    /**
     * Configure permissions for a Site's Guest User
     * This is idempotent - safe to run multiple times
     */
    @AuraEnabled
    public static ConfigResult configurePermissions(String siteId) {
        if (String.isBlank(siteId)) {
            throw createException('Site ID is required');
        }

        ConfigResult result = new ConfigResult();

        try {
            // Get the Site and Guest User info
            Site site = [SELECT Id, GuestUserId FROM Site WHERE Id = :siteId LIMIT 1];
            if (site.GuestUserId == null) {
                throw createException('Site does not have a Guest User configured');
            }

            // Get the Guest User's Profile
            User guestUser = [SELECT ProfileId FROM User WHERE Id = :site.GuestUserId LIMIT 1];

            // Get the PermissionSet linked to this Profile
            List<PermissionSet> profilePS = [
                SELECT Id FROM PermissionSet
                WHERE ProfileId = :guestUser.ProfileId
                LIMIT 1
            ];

            if (profilePS.isEmpty()) {
                throw createException('Could not find Permission Set for Guest User Profile');
            }

            Id permSetId = profilePS[0].Id;

            // Configure object permissions - Read
            for (String objName : REQUIRED_OBJECT_READ) {
                PermissionStatus ps = configureObjectPermission(permSetId, objName, 'Read');
                result.results.add(ps);
            }

            // Configure object permissions - Create
            for (String objName : REQUIRED_OBJECT_CREATE) {
                PermissionStatus ps = configureObjectPermission(permSetId, objName, 'Create');
                result.results.add(ps);
            }

            // Configure field permissions
            for (String objName : REQUIRED_FIELD_READ.keySet()) {
                for (String fieldName : REQUIRED_FIELD_READ.get(objName)) {
                    PermissionStatus ps = configureFieldPermission(permSetId, objName, fieldName);
                    result.results.add(ps);
                }
            }

            // Check for any failures
            result.success = true;
            for (PermissionStatus ps : result.results) {
                if (!ps.configured) {
                    result.success = false;
                    break;
                }
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            result.success = false;
            result.errorMessage = 'Error configuring permissions: ' + e.getMessage();
        }

        return result;
    }

    /**
     * Configure object permission (idempotent)
     */
    private static PermissionStatus configureObjectPermission(Id permSetId, String objectName, String permType) {
        PermissionStatus ps = new PermissionStatus();
        ps.name = objectName + ' ' + permType;
        ps.description = permType + ' access to ' + objectName;
        ps.permissionType = 'Object';
        ps.canAutomate = true;

        try {
            // CRUD checks for ObjectPermissions (setup entity — CRUD checks only, no stripInaccessible)
            Boolean crudDenied = Test.isRunningTest() && testDenyCrud;
            if (crudDenied || !Schema.sObjectType.ObjectPermissions.isAccessible() ||
                !Schema.sObjectType.ObjectPermissions.isCreateable() ||
                !Schema.sObjectType.ObjectPermissions.isUpdateable()) {
                ps.configured = false;
                ps.errorMessage = 'Insufficient permissions to manage ObjectPermissions';
                return ps;
            }

            // Check if permission already exists
            List<ObjectPermissions> existing = [
                SELECT Id, PermissionsRead, PermissionsCreate
                FROM ObjectPermissions
                WHERE ParentId = :permSetId AND SobjectType = :objectName
                LIMIT 1
            ];

            ObjectPermissions objPerm;
            if (!existing.isEmpty()) {
                objPerm = existing[0];
            } else {
                objPerm = new ObjectPermissions(
                    ParentId = permSetId,
                    SobjectType = objectName
                );
            }

            // Set the required permission
            if (permType == 'Read') {
                objPerm.PermissionsRead = true;
            } else if (permType == 'Create') {
                objPerm.PermissionsCreate = true;
                objPerm.PermissionsRead = true; // Create requires Read
            }

            upsert objPerm;
            ps.configured = true;

        } catch (Exception e) {
            ps.configured = false;
            ps.errorMessage = e.getMessage();
            ErrorLogger.log('Failed to configure object permission: ' + objectName + ' ' + permType, e.getStackTraceString(), null);
        }

        return ps;
    }

    /**
     * Configure field permission (idempotent)
     */
    private static PermissionStatus configureFieldPermission(Id permSetId, String objectName, String fieldName) {
        PermissionStatus ps = new PermissionStatus();
        ps.name = objectName + '.' + fieldName + ' Read';
        ps.description = 'Read access to ' + objectName + '.' + fieldName;
        ps.permissionType = 'Field';
        ps.canAutomate = true;

        try {
            // CRUD checks for FieldPermissions (setup entity — CRUD checks only, no stripInaccessible)
            Boolean crudDenied = Test.isRunningTest() && testDenyCrud;
            if (crudDenied || !Schema.sObjectType.FieldPermissions.isAccessible() ||
                !Schema.sObjectType.FieldPermissions.isCreateable() ||
                !Schema.sObjectType.FieldPermissions.isUpdateable()) {
                ps.configured = false;
                ps.errorMessage = 'Insufficient permissions to manage FieldPermissions';
                return ps;
            }

            String fieldKey = objectName + '.' + fieldName;

            // Check if permission already exists
            List<FieldPermissions> existing = [
                SELECT Id, PermissionsRead
                FROM FieldPermissions
                WHERE ParentId = :permSetId AND Field = :fieldKey
                LIMIT 1
            ];

            FieldPermissions fieldPerm;
            if (!existing.isEmpty()) {
                fieldPerm = existing[0];
            } else {
                fieldPerm = new FieldPermissions(
                    ParentId = permSetId,
                    SobjectType = objectName,
                    Field = fieldKey
                );
            }

            fieldPerm.PermissionsRead = true;
            upsert fieldPerm;
            ps.configured = true;

        } catch (Exception e) {
            ps.configured = false;
            ps.errorMessage = e.getMessage();
            ErrorLogger.log('Failed to configure field permission: ' + objectName + '.' + fieldName, e.getStackTraceString(), null);
        }

        return ps;
    }

    /**
     * Validate complete configuration for a Site
     */
    @AuraEnabled
    public static ValidationResult validateConfiguration(String siteId) {
        // Same as getSetupStatus - validates current state
        return getSetupStatus(siteId);
    }

    /**
     * Create a sample "Contact Support" form
     */
    @AuraEnabled
    public static String createSampleForm() {
        try {
            // CRUD checks for Form__c and Form_Field__c
            Boolean crudDenied = Test.isRunningTest() && testDenyCrud;
            if (crudDenied || !Schema.sObjectType.Form__c.isAccessible() || !Schema.sObjectType.Form__c.isCreateable()) {
                throw createException('Insufficient permissions to create Form__c');
            }
            if (crudDenied || !Schema.sObjectType.Form_Field__c.isCreateable()) {
                throw createException('Insufficient permissions to create Form_Field__c');
            }

            // Check if sample form already exists
            List<Form__c> existing = [
                SELECT Id FROM Form__c
                WHERE Form_Name__c = 'contact-support'
                LIMIT 1
            ];

            if (!existing.isEmpty()) {
                return existing[0].Id;
            }

            // Create the sample form
            Form__c form = new Form__c(
                Form_Name__c = 'contact-support',
                Title__c = 'Contact Support',
                Description__c = 'Use this form to submit a support request. We typically respond within 24 hours.',
                Active__c = true,
                Enable_File_Upload__c = true,
                Max_File_Size_MB__c = 10,
                Success_Message__c = 'Thank you for contacting us! Your case has been submitted and you will receive a confirmation email shortly.'
            );
            insert form;

            // Create sample fields
            List<Form_Field__c> fields = new List<Form_Field__c>{
                new Form_Field__c(
                    Form__c = form.Id,
                    Field_Label__c = 'Your Name',
                    Field_Type__c = 'Text',
                    Case_Field__c = 'SuppliedName',
                    Required__c = true,
                    Sort_Order__c = 1
                ),
                new Form_Field__c(
                    Form__c = form.Id,
                    Field_Label__c = 'Email Address',
                    Field_Type__c = 'Email',
                    Case_Field__c = 'SuppliedEmail',
                    Required__c = true,
                    Sort_Order__c = 2
                ),
                new Form_Field__c(
                    Form__c = form.Id,
                    Field_Label__c = 'Subject',
                    Field_Type__c = 'Text',
                    Case_Field__c = 'Subject',
                    Required__c = true,
                    Sort_Order__c = 3
                ),
                new Form_Field__c(
                    Form__c = form.Id,
                    Field_Label__c = 'Description',
                    Field_Type__c = 'Textarea',
                    Case_Field__c = 'Description',
                    Required__c = true,
                    Sort_Order__c = 4
                )
            };
            insert fields;

            return form.Id;

        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            throw createException('Error creating sample form: ' + e.getMessage());
        }
    }

    /**
     * Get the public URL for a form on a Site
     */
    @AuraEnabled
    public static String getPublicUrl(String siteId, String formName) {
        if (String.isBlank(siteId)) {
            throw createException('Site ID is required');
        }

        try {
            Site site = [SELECT Id, Name, Subdomain, UrlPathPrefix FROM Site WHERE Id = :siteId LIMIT 1];
            String baseUrl = getSiteBaseUrl(site);

            if (String.isBlank(baseUrl)) {
                return null;
            }

            // Build the form URL
            // Note: getSiteBaseUrl returns SecureUrl which already includes the path prefix
            String url = baseUrl;
            if (!url.endsWith('/')) {
                url += '/';
            }

            url += 'apex/CaseFormPage';

            // Add form parameter if provided
            if (String.isNotBlank(formName)) {
                url += '?form=' + EncodingUtil.urlEncode(formName, 'UTF-8');
            }

            return url;

        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            throw createException('Error generating public URL: ' + e.getMessage());
        }
    }

    /**
     * Get configuration summary for diagnostics download
     */
    @AuraEnabled
    public static ConfigSummary getConfigSummary(String siteId) {
        if (String.isBlank(siteId)) {
            throw createException('Site ID is required');
        }

        ConfigSummary summary = new ConfigSummary();

        try {
            Site site = [SELECT Id, Name, MasterLabel FROM Site WHERE Id = :siteId LIMIT 1];
            summary.siteName = site.MasterLabel;
            summary.siteUrl = getSiteBaseUrl(site);
            summary.configuredAt = DateTime.now().format('yyyy-MM-dd HH:mm:ss z');
            summary.configuredBy = UserInfo.getName();

            // Get the validation result to list configured permissions
            ValidationResult validation = getSetupStatus(siteId);
            for (PermissionStatus ps : validation.permissions) {
                if (ps.configured) {
                    summary.permissionsApplied.add(ps.name);
                }
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            throw createException('Error generating config summary: ' + e.getMessage());
        }

        return summary;
    }

    /**
     * Get current reCAPTCHA settings
     * Note: Never exposes the actual Secret Key - only indicates if it's set
     */
    @AuraEnabled
    public static ReCaptchaSettingsResult getReCaptchaSettings() {
        ReCaptchaSettingsResult result = new ReCaptchaSettingsResult();

        try {
            reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();

            if (settings != null && settings.Id != null) {
                result.siteKey = settings.Site_Key__c;
                result.hasSecretKey = String.isNotBlank(settings.Secret_Key__c);
                result.isConfigured = String.isNotBlank(settings.Site_Key__c) &&
                                      String.isNotBlank(settings.Secret_Key__c);
                result.captchaType = String.isNotBlank(settings.Captcha_Type__c) ?
                                     settings.Captcha_Type__c : 'V2_Checkbox';
                result.scoreThreshold = settings.Score_Threshold__c != null ?
                                        settings.Score_Threshold__c : 0.3;
            }
        } catch (Exception e) {
            result.errorMessage = 'Error retrieving reCAPTCHA settings: ' + e.getMessage();
            ErrorLogger.logException(e, null);
        }

        return result;
    }

    /**
     * Save reCAPTCHA settings at org level
     * Allows partial updates - if siteKey or secretKey is blank, preserves existing value
     * @param siteKey The public Site Key from Google reCAPTCHA admin (max 255 chars)
     * @param secretKey The private Secret Key from Google reCAPTCHA admin (max 255 chars)
     * @param captchaType The reCAPTCHA type: V2_Checkbox, V2_Invisible, or V3_Score
     * @param scoreThreshold The minimum score for v3 verification (0.0-1.0)
     * @return Result indicating success or failure
     */
    @AuraEnabled
    public static ReCaptchaSettingsResult saveReCaptchaSettings(String siteKey, String secretKey,
                                                                  String captchaType, Decimal scoreThreshold) {
        ReCaptchaSettingsResult result = new ReCaptchaSettingsResult();

        try {
            // CRUD checks for custom settings
            Boolean crudDenied = Test.isRunningTest() && testDenyCrud;
            if (crudDenied || !Schema.sObjectType.reCAPTCHA_Settings__c.isCreateable() ||
                !Schema.sObjectType.reCAPTCHA_Settings__c.isUpdateable()) {
                result.errorMessage = 'Insufficient permissions to save reCAPTCHA settings';
                return result;
            }

            // Trim inputs
            String trimmedSiteKey = String.isNotBlank(siteKey) ? siteKey.trim() : null;
            String trimmedSecretKey = String.isNotBlank(secretKey) ? secretKey.trim() : null;
            String trimmedCaptchaType = String.isNotBlank(captchaType) ? captchaType.trim() : null;

            // Validate field lengths (max 255 chars)
            if (trimmedSiteKey != null && trimmedSiteKey.length() > 255) {
                result.errorMessage = 'Site Key exceeds maximum length of 255 characters.';
                return result;
            }
            if (trimmedSecretKey != null && trimmedSecretKey.length() > 255) {
                result.errorMessage = 'Secret Key exceeds maximum length of 255 characters.';
                return result;
            }

            // Validate captcha type
            Set<String> validTypes = new Set<String>{'V2_Checkbox', 'V2_Invisible', 'V3_Score'};
            if (trimmedCaptchaType != null && !validTypes.contains(trimmedCaptchaType)) {
                result.errorMessage = 'Invalid captcha type. Must be V2_Checkbox, V2_Invisible, or V3_Score.';
                return result;
            }

            // Validate score threshold
            if (scoreThreshold != null && (scoreThreshold < 0 || scoreThreshold > 1)) {
                result.errorMessage = 'Score threshold must be between 0.0 and 1.0.';
                return result;
            }

            // Get existing settings or create new
            reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();

            if (settings == null || settings.Id == null) {
                // Create new org-level settings
                settings = new reCAPTCHA_Settings__c(
                    SetupOwnerId = UserInfo.getOrganizationId()
                );
            }

            // Allow partial updates - only update if new value is provided
            if (trimmedSiteKey != null) {
                settings.Site_Key__c = trimmedSiteKey;
            }
            if (trimmedSecretKey != null) {
                settings.Secret_Key__c = trimmedSecretKey;
            }
            if (trimmedCaptchaType != null) {
                settings.Captcha_Type__c = trimmedCaptchaType;
            }
            if (scoreThreshold != null) {
                settings.Score_Threshold__c = scoreThreshold;
            }

            upsert settings;

            // Set result
            result.siteKey = settings.Site_Key__c;
            result.hasSecretKey = String.isNotBlank(settings.Secret_Key__c);
            result.isConfigured = String.isNotBlank(settings.Site_Key__c) &&
                                  String.isNotBlank(settings.Secret_Key__c);
            result.captchaType = String.isNotBlank(settings.Captcha_Type__c) ?
                                 settings.Captcha_Type__c : 'V2_Checkbox';
            result.scoreThreshold = settings.Score_Threshold__c != null ?
                                    settings.Score_Threshold__c : 0.3;

        } catch (Exception e) {
            result.errorMessage = 'Error saving reCAPTCHA settings: ' + e.getMessage();
            ErrorLogger.logException(e, null);
        }

        return result;
    }

    /**
     * Save the default Site ID and base URL to org settings
     * Called when user selects a Site in the Setup Wizard
     * @param siteId The Salesforce Site ID to set as default
     */
    @AuraEnabled
    public static void saveDefaultSite(String siteId) {
        if (String.isBlank(siteId)) {
            throw createException('Site ID is required');
        }

        try {
            // CRUD checks for custom settings
            Boolean crudDenied = Test.isRunningTest() && testDenyCrud;
            if (crudDenied || !Schema.sObjectType.reCAPTCHA_Settings__c.isCreateable() ||
                !Schema.sObjectType.reCAPTCHA_Settings__c.isUpdateable()) {
                throw createException('Insufficient permissions to save default site settings');
            }

            // Query Site to validate it exists
            Site site = [SELECT Id, Name FROM Site WHERE Id = :siteId LIMIT 1];

            // Get the base URL for this Site
            String baseUrl = getSiteBaseUrl(site);

            // Get or create org-level settings
            reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();
            if (settings == null || settings.Id == null) {
                settings = new reCAPTCHA_Settings__c(
                    SetupOwnerId = UserInfo.getOrganizationId()
                );
            }

            settings.Default_Site_Id__c = siteId;
            settings.Default_Site_Base_Url__c = baseUrl;
            upsert settings;

        } catch (QueryException e) {
            ErrorLogger.logException(e, null);
            throw createException('Invalid Site ID: Site not found');
        } catch (Exception e) {
            ErrorLogger.logException(e, null);
            throw createException('Error saving default Site: ' + e.getMessage());
        }
    }

    /**
     * Clear reCAPTCHA settings
     */
    @AuraEnabled
    public static ReCaptchaSettingsResult clearReCaptchaSettings() {
        ReCaptchaSettingsResult result = new ReCaptchaSettingsResult();

        try {
            // CRUD checks for custom settings
            Boolean crudDenied = Test.isRunningTest() && testDenyCrud;
            if (crudDenied || !Schema.sObjectType.reCAPTCHA_Settings__c.isUpdateable()) {
                result.errorMessage = 'Insufficient permissions to clear reCAPTCHA settings';
                return result;
            }

            reCAPTCHA_Settings__c settings = reCAPTCHA_Settings__c.getOrgDefaults();

            if (settings != null && settings.Id != null) {
                settings.Site_Key__c = null;
                settings.Secret_Key__c = null;
                update settings;
            }

            result.isConfigured = false;
            result.hasSecretKey = false;
            result.siteKey = null;

        } catch (Exception e) {
            result.errorMessage = 'Error clearing reCAPTCHA settings: ' + e.getMessage();
            ErrorLogger.logException(e, null);
        }

        return result;
    }
}
