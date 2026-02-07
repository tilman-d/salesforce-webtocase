/**
 * Test class for FileAssemblyQueueable
 * Tests async chunk assembly into single ContentVersion
 */
@isTest
private class FileAssemblyQueueableTest {

    /**
     * Helper: create a Case for testing
     */
    private static Case createTestCase() {
        Case testCase = new Case(Subject = 'Test Async Upload', Status = 'New');
        insert testCase;
        return testCase;
    }

    /**
     * Helper: create chunk ContentVersions linked to a Case
     * Uses FirstPublishLocationId to link chunks to the Case (same as production code)
     */
    private static String createChunks(String caseId, String fileName, List<String> chunkContents) {
        String uploadKey = 'test-async-key-' + System.now().getTime();
        Integer totalChunks = chunkContents.size();

        for (Integer i = 0; i < totalChunks; i++) {
            String chunkTitle = '__chunk__' + uploadKey + '__' + i + '__' + totalChunks + '__' + fileName;
            ContentVersion cv = new ContentVersion();
            cv.Title = chunkTitle;
            cv.PathOnClient = chunkTitle + '.tmp';
            cv.VersionData = Blob.valueOf(chunkContents[i]);
            cv.FirstPublishLocationId = caseId;
            insert cv;
        }

        return uploadKey;
    }

    /**
     * Test successful assembly of 4 chunks into a single ContentVersion
     */
    @isTest
    static void testSuccessfulAssembly() {
        Case testCase = createTestCase();
        String fileName = 'test-document.pdf';

        // Create 4 chunks (triggers async path in production: totalChunks > 3)
        // IMPORTANT: Non-last chunk byte lengths must be divisible by 3 for clean base64
        // concatenation (no intermediate padding). This mirrors production CHUNK_SIZE = 750,000.
        List<String> chunkContents = new List<String>{
            'aaa',  // 3 bytes - divisible by 3, no base64 padding
            'bbb',  // 3 bytes
            'ccc',  // 3 bytes
            'ddd'   // last chunk can have any length
        };
        String uploadKey = createChunks(testCase.Id, fileName, chunkContents);

        Test.startTest();
        System.enqueueJob(new FileAssemblyQueueable(testCase.Id, uploadKey, fileName, 4));
        Test.stopTest(); // Forces Queueable to execute synchronously

        // Verify final file exists on the Case
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testCase.Id
        ];

        // Find the final (non-chunk) ContentVersion
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdls) {
            docIds.add(cdl.ContentDocumentId);
        }

        List<ContentVersion> finalFiles = [
            SELECT Title, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND Title = :fileName
              AND IsLatest = true
        ];

        System.assertEquals(1, finalFiles.size(), 'Should have exactly one final file');
        System.assertEquals(fileName, finalFiles[0].Title, 'File name should match');

        // Verify combined content matches original chunks
        String expectedContent = 'aaabbbcccddd';
        System.assertEquals(expectedContent, finalFiles[0].VersionData.toString(), 'Combined content should match all chunks');
    }

    /**
     * Test that chunk files are cleaned up after successful assembly
     */
    @isTest
    static void testChunkCleanup() {
        Case testCase = createTestCase();
        String fileName = 'cleanup-test.txt';

        List<String> chunkContents = new List<String>{ 'aaa', 'bbb', 'ccc', 'ddd' };
        String uploadKey = createChunks(testCase.Id, fileName, chunkContents);

        // Verify chunks exist before assembly
        String chunkPattern = '__chunk__' + uploadKey + '%';
        List<ContentVersion> chunksBefore = [
            SELECT Id FROM ContentVersion WHERE Title LIKE :chunkPattern
        ];
        System.assertEquals(4, chunksBefore.size(), 'Should have 4 chunks before assembly');

        Test.startTest();
        System.enqueueJob(new FileAssemblyQueueable(testCase.Id, uploadKey, fileName, 4));
        Test.stopTest();

        // Verify chunks are cleaned up after assembly
        String chunkPatternAfter = '__chunk__' + uploadKey + '%';
        List<ContentVersion> chunksAfter = [
            SELECT Id FROM ContentVersion WHERE Title LIKE :chunkPatternAfter
        ];
        System.assertEquals(0, chunksAfter.size(), 'Chunk files should be deleted after assembly');
    }

    /**
     * Test idempotency: running assembly twice should not create duplicate files
     */
    @isTest
    static void testIdempotency() {
        Case testCase = createTestCase();
        String fileName = 'idempotent-test.txt';

        // Use 3-byte chunks for clean base64 concatenation (no intermediate padding)
        List<String> chunkContents = new List<String>{ 'aaa', 'bbb', 'ccc', 'ddd' };
        String uploadKey = createChunks(testCase.Id, fileName, chunkContents);

        // First assembly via Queueable
        Test.startTest();
        System.enqueueJob(new FileAssemblyQueueable(testCase.Id, uploadKey, fileName, 4));
        Test.stopTest();

        // Verify one file exists
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :testCase.Id
        ];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdls) {
            docIds.add(cdl.ContentDocumentId);
        }
        List<ContentVersion> filesAfterFirst = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND Title = :fileName AND IsLatest = true
        ];
        System.assertEquals(1, filesAfterFirst.size(), 'Should have one file after first assembly');

        // Second assembly attempt (idempotency test)
        // Re-create chunks since they were cleaned up
        String uploadKey2 = createChunks(testCase.Id, fileName, chunkContents);

        // Call execute() directly since Test.startTest() can only be used once per test method
        FileAssemblyQueueable q2 = new FileAssemblyQueueable(testCase.Id, uploadKey2, fileName, 4);
        q2.execute(null);

        // Verify still only one final file (idempotency guard should prevent second assembly)
        List<ContentDocumentLink> cdls2 = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :testCase.Id
        ];
        Set<Id> docIds2 = new Set<Id>();
        for (ContentDocumentLink cdl : cdls2) {
            docIds2.add(cdl.ContentDocumentId);
        }
        List<ContentVersion> filesAfterSecond = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId IN :docIds2 AND Title = :fileName
              AND IsLatest = true
        ];
        System.assertEquals(1, filesAfterSecond.size(), 'Idempotency guard should prevent duplicate file');
    }

    /**
     * Test error handling when chunks are missing (count mismatch)
     */
    @isTest
    static void testMissingChunks() {
        Case testCase = createTestCase();
        String fileName = 'missing-chunks-test.txt';

        // Only create 2 chunks but tell Queueable to expect 4
        List<String> chunkContents = new List<String>{ 'aaa', 'bbb' };
        String uploadKey = createChunks(testCase.Id, fileName, chunkContents);

        Test.startTest();
        System.enqueueJob(new FileAssemblyQueueable(testCase.Id, uploadKey, fileName, 4));
        Test.stopTest();

        // Verify no final file was created (assembly should have aborted)
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :testCase.Id
        ];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdls) {
            docIds.add(cdl.ContentDocumentId);
        }
        List<ContentVersion> finalFiles = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND Title = :fileName AND IsLatest = true
        ];
        System.assertEquals(0, finalFiles.size(), 'No final file should exist when chunks are missing');

        // Verify an error was logged
        List<Error_Log__c> errors = [
            SELECT Error_Message__c FROM Error_Log__c
            WHERE Form_Id__c = :testCase.Id
        ];
        System.assert(!errors.isEmpty(), 'An error should be logged for chunk mismatch');
        System.assert(errors[0].Error_Message__c.contains('Chunk count mismatch'), 'Error message should mention chunk count mismatch');
    }

    /**
     * Test assembly with no existing links on Case (edge case)
     */
    @isTest
    static void testNoChunksOnCase() {
        Case testCase = createTestCase();
        String fileName = 'no-chunks.txt';

        Test.startTest();
        // Enqueue with uploadKey that doesn't match any chunks
        System.enqueueJob(new FileAssemblyQueueable(testCase.Id, 'nonexistent-key', fileName, 4));
        Test.stopTest();

        // Verify no final file was created
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :testCase.Id
        ];
        // Should have logged an error
        List<Error_Log__c> errors = [
            SELECT Error_Message__c FROM Error_Log__c
            WHERE Form_Id__c = :testCase.Id
        ];
        System.assert(!errors.isEmpty(), 'An error should be logged when no matching chunks found');
    }
}
