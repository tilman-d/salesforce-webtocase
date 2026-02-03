/**
 * WebToCaseNonceService - Manages one-time nonces for embed widget security
 * Uses Platform Cache to store nonces with automatic expiry
 */
public class WebToCaseNonceService {

    // Cache partition name (must be created in Setup > Platform Cache)
    private static final String CACHE_PARTITION = 'local.WebToCase';

    // Nonce TTL in seconds (15 minutes)
    private static final Integer NONCE_TTL_SECONDS = 900;

    // Nonce prefix for cache keys
    private static final String NONCE_PREFIX = 'nonce_';

    // In-memory fallback for test context (Platform Cache unavailable)
    @TestVisible
    private static Map<String, String> testModeCache = new Map<String, String>();

    // Flag to track if Platform Cache is available
    @TestVisible
    private static Boolean cacheAvailable = null;

    /**
     * Wrapper class for nonce data
     */
    public class NonceData {
        public String nonceId;
        public String formId;
        public String origin;
        public Long expiresAt;
        public List<String> allowedFields;

        public NonceData() {
            this.allowedFields = new List<String>();
        }
    }

    /**
     * Generate a new nonce for a form request
     * @param formId The Form__c record ID
     * @param origin The validated origin domain
     * @param allowedFields List of allowed field API names for this form
     * @return The generated nonce ID
     */
    public static String generateNonce(String formId, String origin, List<String> allowedFields) {
        // Generate a cryptographically secure random nonce
        String nonceId = generateSecureRandomId();

        // Create nonce data
        NonceData data = new NonceData();
        data.nonceId = nonceId;
        data.formId = formId;
        data.origin = origin;
        data.expiresAt = System.currentTimeMillis() + (NONCE_TTL_SECONDS * 1000);
        data.allowedFields = allowedFields;

        // Store in cache
        String cacheKey = NONCE_PREFIX + nonceId;
        String serializedData = JSON.serialize(data);

        // Try Platform Cache first, fall back to in-memory for test context
        if (isCacheAvailable()) {
            try {
                Cache.Org.put(cacheKey, serializedData, NONCE_TTL_SECONDS);
            } catch (Cache.CacheException e) {
                // Fallback to in-memory cache
                testModeCache.put(cacheKey, serializedData);
            }
        } else {
            // Use in-memory cache (test context or cache not configured)
            testModeCache.put(cacheKey, serializedData);
        }

        return nonceId;
    }

    /**
     * Validate and consume a nonce (one-time use)
     * Returns null if nonce is invalid, expired, or already used
     * @param nonceId The nonce ID to validate
     * @param formId Expected form ID
     * @param origin Expected origin
     * @return NonceData if valid, null otherwise
     */
    public static NonceData validateAndConsume(String nonceId, String formId, String origin) {
        if (String.isBlank(nonceId)) {
            return null;
        }

        String cacheKey = NONCE_PREFIX + nonceId;

        try {
            Object cached = null;

            // Try Platform Cache first, then in-memory fallback
            if (isCacheAvailable()) {
                try {
                    // Atomically get and remove the nonce
                    cached = Cache.Org.remove(cacheKey);
                } catch (Cache.CacheException e) {
                    // Try in-memory fallback
                    cached = testModeCache.remove(cacheKey);
                }
            } else {
                // Use in-memory cache (test context or cache not configured)
                cached = testModeCache.remove(cacheKey);
            }

            if (cached == null) {
                // Nonce not found (expired, already used, or never existed)
                return null;
            }

            // Deserialize nonce data
            NonceData data = (NonceData) JSON.deserialize((String) cached, NonceData.class);

            // Validate expiry (double-check even though cache has TTL)
            if (data.expiresAt < System.currentTimeMillis()) {
                return null;
            }

            // Validate form ID matches
            if (data.formId != formId) {
                ErrorLogger.log('Nonce form ID mismatch',
                    'Expected: ' + data.formId + ', Got: ' + formId,
                    formId);
                return null;
            }

            // Validate origin matches
            if (!String.isBlank(data.origin) && data.origin != origin) {
                ErrorLogger.log('Nonce origin mismatch',
                    'Expected: ' + data.origin + ', Got: ' + origin,
                    formId);
                return null;
            }

            return data;

        } catch (Cache.CacheException e) {
            ErrorLogger.log('Platform Cache error during nonce validation', e.getMessage(), formId);
            return null;
        } catch (Exception e) {
            ErrorLogger.logException(e, formId);
            return null;
        }
    }

    /**
     * Check if a field is allowed based on nonce data
     * @param nonceData The validated nonce data
     * @param fieldName The field name to check
     * @return true if field is allowed, false otherwise
     */
    public static Boolean isFieldAllowed(NonceData nonceData, String fieldName) {
        if (nonceData == null || nonceData.allowedFields == null) {
            return false;
        }
        return nonceData.allowedFields.contains(fieldName);
    }

    /**
     * Generate a cryptographically secure random ID
     * Uses Crypto.generateAesKey for randomness
     */
    private static String generateSecureRandomId() {
        // Generate 256-bit random key and encode as hex
        Blob randomBytes = Crypto.generateAesKey(256);
        return EncodingUtil.convertToHex(randomBytes);
    }

    /**
     * Check if Platform Cache is available
     * Caches the result for performance
     */
    private static Boolean isCacheAvailable() {
        if (cacheAvailable != null) {
            return cacheAvailable;
        }

        // In test context, always use in-memory cache for reliability
        if (Test.isRunningTest()) {
            cacheAvailable = false;
            return false;
        }

        // Check if Platform Cache partition exists
        try {
            // Try to get a non-existent key - this will throw if partition doesn't exist
            Cache.Org.get('__test_key__');
            cacheAvailable = true;
        } catch (Cache.Org.OrgCacheException e) {
            cacheAvailable = false;
        } catch (Exception e) {
            cacheAvailable = false;
        }

        return cacheAvailable;
    }

    /**
     * Custom exception for nonce-related errors
     */
    public class NonceException extends Exception {}
}
