/**
 * WebToCaseRateLimiter - Rate limiting for embed widget submissions
 * Tracks submissions per origin per hour using Rate_Limit_Counter__c
 */
public class WebToCaseRateLimiter {

    // Default rate limit: 100 submissions per origin per hour
    private static final Integer DEFAULT_RATE_LIMIT = 100;

    // Cleanup threshold: delete counters older than this many hours
    private static final Integer CLEANUP_HOURS = 24;

    /**
     * Result of a rate limit check
     */
    public class RateLimitResult {
        public Boolean allowed;
        public Integer currentCount;
        public Integer limit_x; // 'limit' is reserved
        public Integer retryAfterSeconds;

        public RateLimitResult(Boolean allowed, Integer currentCount, Integer limit_x) {
            this.allowed = allowed;
            this.currentCount = currentCount;
            this.limit_x = limit_x;
            this.retryAfterSeconds = 0;
        }
    }

    /**
     * Check if a submission is allowed and increment the counter
     * @param origin The origin domain making the request
     * @return RateLimitResult indicating if request is allowed
     */
    public static RateLimitResult checkAndIncrement(String origin) {
        Integer rateLimit = DEFAULT_RATE_LIMIT;

        // Get current hour bucket (truncate to hour)
        DateTime now = DateTime.now();
        DateTime hourBucket = DateTime.newInstance(
            now.year(), now.month(), now.day(), now.hour(), 0, 0
        );

        // Create a unique key for this origin + hour
        String originKey = generateOriginKey(origin, hourBucket);

        // Try to find existing counter using FOR UPDATE to lock row
        List<Rate_Limit_Counter__c> counters = [
            SELECT Id, Count__c, Hour_Bucket__c
            FROM Rate_Limit_Counter__c
            WHERE Origin_Key__c = :originKey
            FOR UPDATE
        ];

        Integer currentCount;

        if (counters.isEmpty()) {
            // Create new counter
            Rate_Limit_Counter__c newCounter = new Rate_Limit_Counter__c(
                Origin_Key__c = originKey,
                Origin_Domain__c = origin,
                Count__c = 1,
                Hour_Bucket__c = hourBucket
            );

            try {
                insert newCounter;
                currentCount = 1;
            } catch (DmlException e) {
                // Possible duplicate insert race condition - retry query
                counters = [
                    SELECT Id, Count__c
                    FROM Rate_Limit_Counter__c
                    WHERE Origin_Key__c = :originKey
                    FOR UPDATE
                ];

                if (!counters.isEmpty()) {
                    Rate_Limit_Counter__c counter = counters[0];
                    counter.Count__c = counter.Count__c + 1;
                    update counter;
                    currentCount = (Integer) counter.Count__c;
                } else {
                    // Something else went wrong
                    ErrorLogger.log('Rate limit counter creation failed', e.getMessage(), null);
                    // Allow the request but log the issue
                    return new RateLimitResult(true, 1, rateLimit);
                }
            }
        } else {
            // Increment existing counter
            Rate_Limit_Counter__c counter = counters[0];
            counter.Count__c = counter.Count__c + 1;
            update counter;
            currentCount = (Integer) counter.Count__c;
        }

        // Check if over limit
        if (currentCount > rateLimit) {
            RateLimitResult result = new RateLimitResult(false, currentCount, rateLimit);
            // Calculate seconds until next hour
            DateTime nextHour = hourBucket.addHours(1);
            result.retryAfterSeconds = (Integer) ((nextHour.getTime() - now.getTime()) / 1000);

            // Log rate limit event
            ErrorLogger.log('Rate limit exceeded',
                'Origin: ' + origin + ', Count: ' + currentCount + ', Limit: ' + rateLimit,
                null);

            return result;
        }

        return new RateLimitResult(true, currentCount, rateLimit);
    }

    /**
     * Generate a unique key for origin + hour bucket
     * Uses SHA-256 hash of origin + timestamp
     */
    private static String generateOriginKey(String origin, DateTime hourBucket) {
        String rawKey = origin + '|' + hourBucket.format('yyyy-MM-dd-HH');
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(rawKey));
        return EncodingUtil.convertToHex(hash);
    }

    /**
     * Cleanup old rate limit counters (call from scheduled job)
     * Deletes counters older than CLEANUP_HOURS
     */
    public static void cleanupOldCounters() {
        DateTime cutoff = DateTime.now().addHours(-CLEANUP_HOURS);

        List<Rate_Limit_Counter__c> oldCounters = [
            SELECT Id
            FROM Rate_Limit_Counter__c
            WHERE Hour_Bucket__c < :cutoff
            LIMIT 10000
        ];

        if (!oldCounters.isEmpty()) {
            delete oldCounters;
        }
    }

    /**
     * Get current count for an origin (for monitoring/debugging)
     * @param origin The origin domain
     * @return Current count for this hour, or 0 if not found
     */
    public static Integer getCurrentCount(String origin) {
        DateTime now = DateTime.now();
        DateTime hourBucket = DateTime.newInstance(
            now.year(), now.month(), now.day(), now.hour(), 0, 0
        );

        String originKey = generateOriginKey(origin, hourBucket);

        List<Rate_Limit_Counter__c> counters = [
            SELECT Count__c
            FROM Rate_Limit_Counter__c
            WHERE Origin_Key__c = :originKey
            LIMIT 1
        ];

        if (counters.isEmpty()) {
            return 0;
        }

        return (Integer) counters[0].Count__c;
    }
}
