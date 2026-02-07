/**
 * FileAssemblyQueueable - Assembles chunked file uploads in async context
 * Uses Queueable (12MB async heap) to support files up to ~4MB,
 * bypassing the 6MB synchronous heap limit.
 *
 * Files <= 2MB (3 chunks) are still assembled synchronously in CaseFormController.
 * This Queueable handles files > 2MB (4+ chunks).
 *
 * IMPORTANT: CHUNK_SIZE (750,000 bytes) must remain divisible by 3 to ensure
 * intermediate base64 chunks have no padding. Only the last chunk may have padding,
 * correctly positioned at the end of the concatenated string.
 * 750,000 / 3 = 250,000 (no remainder).
 */
public class FileAssemblyQueueable implements Queueable {

    private String caseId;
    private String uploadKey;
    private String fileName;
    private Integer totalChunks;

    public FileAssemblyQueueable(String caseId, String uploadKey, String fileName, Integer totalChunks) {
        this.caseId = caseId;
        // Sanitize uploadKey: strip double-underscores to prevent title parsing issues
        this.uploadKey = uploadKey != null ? uploadKey.replace('__', '-') : uploadKey;
        this.fileName = fileName;
        this.totalChunks = totalChunks;
    }

    public void execute(QueueableContext context) {
        try {
            // Idempotency guard: check if final file already exists on this Case
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
            ];

            Set<Id> existingDocIds = new Set<Id>();
            for (ContentDocumentLink link : existingLinks) {
                existingDocIds.add(link.ContentDocumentId);
            }

            if (!existingDocIds.isEmpty()) {
                // Title = :fileName already ensures exact match, so no need for NOT LIKE filter
                List<ContentVersion> existingFiles = [
                    SELECT Id
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :existingDocIds
                      AND Title = :fileName
                      AND IsLatest = true
                    LIMIT 1
                ];

                if (!existingFiles.isEmpty()) {
                    // Final file already exists - skip assembly (idempotency)
                    System.debug('FileAssemblyQueueable: Final file already exists for ' + fileName + ', skipping assembly');
                    return;
                }
            }

            // Query all chunk metadata (no VersionData) linked to this Case
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :caseId
            ];

            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink link : links) {
                docIds.add(link.ContentDocumentId);
            }

            String chunkPattern = '__chunk__' + uploadKey + '__%';
            List<ContentVersion> chunkMeta = [
                SELECT Id, Title, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND Title LIKE :chunkPattern
                ORDER BY Title ASC
            ];

            // Verify we have all chunks
            if (chunkMeta.size() != totalChunks) {
                ErrorLogger.log(
                    'FileAssemblyQueueable: Chunk count mismatch. Expected ' + totalChunks + ', found ' + chunkMeta.size(),
                    'uploadKey=' + uploadKey + ', caseId=' + caseId,
                    caseId
                );
                return;
            }

            // Build map of chunk index to ContentVersion Id
            Map<Integer, Id> chunkIdMap = new Map<Integer, Id>();
            Set<Id> chunkDocIdsToDelete = new Set<Id>();

            for (ContentVersion chunk : chunkMeta) {
                // Parse chunk index from title: __chunk__{uploadKey}__{chunkIndex}__{totalChunks}__{fileName}
                String[] parts = chunk.Title.split('__');
                if (parts.size() >= 4) {
                    Integer idx = Integer.valueOf(parts[3]);
                    chunkIdMap.put(idx, chunk.Id);
                    chunkDocIdsToDelete.add(chunk.ContentDocumentId);
                }
            }

            // Assemble using List<String> + String.join() for optimized peak memory
            // Peak during join: list_total + joined_string = F*4/3 + F*4/3 = F*8/3
            // For F=4MB: 4*8/3 = ~10.67MB, well within 12MB async heap
            List<String> base64Chunks = new List<String>();
            for (Integer i = 0; i < totalChunks; i++) {
                if (!chunkIdMap.containsKey(i)) {
                    ErrorLogger.log(
                        'FileAssemblyQueueable: Missing chunk ' + i,
                        'uploadKey=' + uploadKey + ', caseId=' + caseId,
                        caseId
                    );
                    return;
                }

                ContentVersion chunk = [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE Id = :chunkIdMap.get(i)
                    LIMIT 1
                ];

                base64Chunks.add(EncodingUtil.base64Encode(chunk.VersionData));
            }

            String combinedBase64 = String.join(base64Chunks, '');
            base64Chunks = null; // Release list memory

            // Decode the complete file
            Blob completeFile = EncodingUtil.base64Decode(combinedBase64);
            combinedBase64 = null; // Release string memory

            // Create the final ContentVersion
            ContentVersion finalCv = new ContentVersion();
            finalCv.Title = fileName;
            finalCv.PathOnClient = fileName;
            finalCv.VersionData = completeFile;
            insert finalCv;

            // Get the ContentDocumentId
            ContentVersion insertedCv = [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id = :finalCv.Id
            ];

            // Link file to Case
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = insertedCv.ContentDocumentId;
            cdl.LinkedEntityId = caseId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            // Clean up chunk files
            try {
                if (!chunkDocIdsToDelete.isEmpty()) {
                    delete [SELECT Id FROM ContentDocument WHERE Id IN :chunkDocIdsToDelete];
                }
            } catch (Exception cleanupEx) {
                // Log but don't fail - the file was successfully uploaded
                System.debug('FileAssemblyQueueable: Chunk cleanup failed: ' + cleanupEx.getMessage());
            }

        } catch (Exception e) {
            ErrorLogger.logException(e, caseId);
        }
    }
}
