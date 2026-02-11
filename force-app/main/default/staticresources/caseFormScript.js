/* global formConfig, grecaptcha, imageCompression, Visualforce */
/* eslint @lwc/lwc/no-inner-html: "off" */
/**
 * Web-to-Case Form Script
 * Handles form validation, file upload (including chunked uploads for large files),
 * reCAPTCHA (v2 Checkbox, v2 Invisible, v3 Score), and submission via Visualforce Remoting
 */
(function() {
    'use strict';

    // Global callback for v2 Invisible reCAPTCHA
    var captchaResolve = null;
    window.onCaptchaSuccess = function(token) {
        if (captchaResolve) {
            captchaResolve(token);
            captchaResolve = null;
        }
    };

    // Chunk size for large file uploads (750KB to stay under VF Remoting limits)
    // When base64 encoded, this becomes ~1MB
    var CHUNK_SIZE = 750000;

    // Image compression settings
    // Target 0.7MB raw -> ~0.93MB base64 (fits in single request under 1MB VF Remoting limit)
    // This avoids chunked upload which has reliability issues with guest users
    var TARGET_SIZE_MB = 0.7;
    var MAX_IMAGE_SIZE = 25 * 1024 * 1024; // 25MB for images (will be compressed)
    var MAX_DOC_SIZE = 4 * 1024 * 1024;    // 4MB for non-image files (async assembly supports up to ~4MB)

    // Supported image MIME types for compression
    var SUPPORTED_IMAGE_TYPES = [
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/bmp',
        'image/heic',
        'image/heif'
    ];

    /**
     * Check if file is a supported image type
     */
    function isSupportedImage(file) {
        // Check MIME type first
        if (SUPPORTED_IMAGE_TYPES.indexOf(file.type) !== -1) {
            return true;
        }
        // Fallback to extension check (for cases where MIME type is missing)
        var fileName = file.name.toLowerCase();
        return /\.(jpg|jpeg|png|webp|bmp|heic|heif)$/.test(fileName);
    }

    /**
     * Check if file is a video
     */
    function isVideo(file) {
        return file.type && file.type.startsWith('video/');
    }

    /**
     * Validate file before processing
     * @returns {Object} { valid: boolean, error: string|null }
     */
    function validateFile(file) {
        // Videos not supported
        if (isVideo(file)) {
            return {
                valid: false,
                error: 'Video files are not supported. Please email your video to support after submitting this form.'
            };
        }

        // Image files: max 25MB (will be compressed)
        if (isSupportedImage(file) && file.size > MAX_IMAGE_SIZE) {
            return {
                valid: false,
                error: 'Image too large. Images must be under 25MB.'
            };
        }

        // Non-image files: max 2MB
        if (!isSupportedImage(file) && file.size > MAX_DOC_SIZE) {
            return {
                valid: false,
                error: 'File too large. Documents must be under 4MB. For larger files, please email them after submitting.'
            };
        }

        return { valid: true };
    }

    /**
     * Update submit button text (used for compression progress)
     */
    function updateButtonText(text) {
        var submitButton = document.getElementById('submitButton');
        if (submitButton) {
            submitButton.textContent = text;
        }
    }

    /**
     * Compress image if needed (uses browser-image-compression library)
     * Only compresses images larger than TARGET_SIZE_MB
     * @param {File} file - The file to potentially compress
     * @returns {Promise<File|Blob>} - The original or compressed file
     */
    function compressImageIfNeeded(file) {
        return new Promise(function(resolve) {
            // Not an image? Return as-is
            if (!isSupportedImage(file)) {
                resolve(file);
                return;
            }

            // Already under target size? No compression needed
            var targetBytes = TARGET_SIZE_MB * 1024 * 1024;
            if (file.size <= targetBytes) {
                console.log('CaseForm: Image already under ' + TARGET_SIZE_MB + 'MB, no compression needed');
                resolve(file);
                return;
            }

            // Check if imageCompression library is available
            if (typeof imageCompression === 'undefined') {
                console.warn('CaseForm: imageCompression library not loaded, using original file');
                resolve(file);
                return;
            }

            updateButtonText('Optimizing image...');
            var originalSizeMB = (file.size / 1024 / 1024).toFixed(1);
            console.log('CaseForm: Compressing image from ' + originalSizeMB + 'MB');

            var options = {
                maxSizeMB: TARGET_SIZE_MB,
                maxWidthOrHeight: 2560,       // Prevent huge canvas (OOM protection on mobile)
                useWebWorker: true,           // Non-blocking compression
                initialQuality: 0.85,         // Start at 85% quality, reduce if needed
                preserveExif: false,          // Strip EXIF for privacy (GPS, device info)
                fileType: 'image/jpeg',       // Convert HEIC/PNG to JPEG for smaller size
                onProgress: function(progress) {
                    updateButtonText('Optimizing... ' + Math.round(progress) + '%');
                }
            };

            imageCompression(file, options)
                .then(function(compressedFile) {
                    var compressedSizeMB = (compressedFile.size / 1024 / 1024).toFixed(1);
                    console.log('CaseForm: Compressed ' + originalSizeMB + 'MB → ' + compressedSizeMB + 'MB');
                    resolve(compressedFile);
                })
                .catch(function(error) {
                    console.error('CaseForm: Compression failed, using original:', error);
                    // Fallback: return original file (may fail at upload, but let server handle it)
                    resolve(file);
                });
        });
    }

    // postMessage helpers for embed mode
    function postMessageToParent(type, data) {
        if (formConfig && formConfig.isEmbedMode && window.parent !== window) {
            window.parent.postMessage({
                type: 'wtc:' + type,
                version: 1,
                ...data
            }, '*'); // Note: In production, use specific origin
        }
    }

    function notifyResize() {
        if (formConfig && formConfig.isEmbedMode) {
            var height = document.body.scrollHeight;
            postMessageToParent('resize', { height: height });
        }
    }

    // Wait for DOM to be ready
    document.addEventListener('DOMContentLoaded', init);

    function init() {
        var form = document.getElementById('caseForm');
        if (!form) {
            console.log('CaseForm: Form element not found');
            return;
        }

        // Check for formConfig
        if (typeof formConfig === 'undefined') {
            console.error('CaseForm: formConfig not defined');
            return;
        }

        console.log('CaseForm: Initializing with formId:', formConfig.formId);
        if (formConfig.enableCaptcha) {
            console.log('CaseForm: reCAPTCHA is enabled, type:', formConfig.captchaType);
        }

        // Notify parent in embed mode
        if (formConfig.isEmbedMode) {
            postMessageToParent('ready', {});
            // Notify resize after a short delay to let styles settle
            setTimeout(notifyResize, 100);
            // Also notify on window resize
            window.addEventListener('resize', notifyResize);
        }

        // Attach submit handler
        form.addEventListener('submit', handleSubmit);

        // Clear error styling on input
        var inputs = form.querySelectorAll('.form-input');
        inputs.forEach(function(input) {
            input.addEventListener('input', function() {
                this.classList.remove('error');
                hideError();
            });
        });
    }

    /**
     * Execute reCAPTCHA and return token via Promise
     * Handles v2 Checkbox (sync), v2 Invisible (callback), and v3 Score (async)
     */
    function executeCaptcha() {
        return new Promise(function(resolve, reject) {
            if (!formConfig.enableCaptcha) {
                resolve('');
                return;
            }

            var captchaType = formConfig.captchaType || 'V2_Checkbox';

            if (captchaType === 'V2_Invisible') {
                // v2 Invisible - execute triggers challenge, callback receives token
                if (typeof grecaptcha === 'undefined') {
                    reject(new Error('reCAPTCHA not loaded'));
                    return;
                }
                captchaResolve = resolve;
                try {
                    grecaptcha.execute();
                } catch (e) {
                    captchaResolve = null;
                    reject(e);
                }
            } else if (captchaType === 'V3_Score') {
                // v3 Score - async execution with action
                if (typeof grecaptcha === 'undefined') {
                    reject(new Error('reCAPTCHA not loaded'));
                    return;
                }
                grecaptcha.ready(function() {
                    grecaptcha.execute(formConfig.captchaSiteKey, { action: 'submit' })
                        .then(function(token) {
                            resolve(token);
                        })
                        .catch(function(err) {
                            reject(err);
                        });
                });
            } else {
                // v2 Checkbox - synchronous retrieval
                if (typeof grecaptcha !== 'undefined') {
                    try {
                        var token = grecaptcha.getResponse();
                        resolve(token);
                    } catch (e) {
                        console.error('CaseForm: Error getting reCAPTCHA response:', e);
                        resolve('');
                    }
                } else {
                    resolve('');
                }
            }
        });
    }

    /**
     * Handle form submission
     */
    function handleSubmit(e) {
        e.preventDefault();

        var form = e.target;

        // Validate form
        var validationErrors = validateForm(form);
        if (validationErrors.length > 0) {
            showError(validationErrors.join('<br>'));
            return;
        }

        var captchaType = formConfig.captchaType || 'V2_Checkbox';

        // For v2 Checkbox, validate synchronously first
        if (formConfig.enableCaptcha && captchaType === 'V2_Checkbox') {
            if (typeof grecaptcha !== 'undefined') {
                var token = grecaptcha.getResponse();
                if (!token) {
                    showCaptchaError();
                    showError('Please complete the CAPTCHA verification.');
                    return;
                }
                hideCaptchaError();
            }
        }

        // Collect field values
        var fieldValues = collectFieldValues(form);

        // Check for file
        var fileInput = document.getElementById('fileInput');
        var hasFile = fileInput && fileInput.files && fileInput.files.length > 0;
        var file = hasFile ? fileInput.files[0] : null;
        // File validation (size limits) handled in processSubmission via validateFile()

        setLoading(true);

        // For v3 and v2 Invisible, get fresh token right before submission
        // For v2 Checkbox, we already have the token
        if (formConfig.enableCaptcha && (captchaType === 'V3_Score' || captchaType === 'V2_Invisible')) {
            executeCaptcha()
                .then(function(captchaToken) {
                    if (!captchaToken && captchaType === 'V2_Invisible') {
                        // v2 Invisible should always return a token after challenge
                        setLoading(false);
                        showCaptchaError();
                        showError('CAPTCHA verification failed. Please try again.');
                        return;
                    }
                    processSubmission(form, fieldValues, file, captchaToken);
                })
                .catch(function(err) {
                    setLoading(false);
                    console.error('CaseForm: reCAPTCHA error:', err);
                    showError('Could not verify. Please check your connection and try again.');
                });
        } else {
            // v2 Checkbox or captcha disabled
            var captchaToken = '';
            if (formConfig.enableCaptcha && typeof grecaptcha !== 'undefined') {
                captchaToken = grecaptcha.getResponse();
            }
            processSubmission(form, fieldValues, file, captchaToken);
        }
    }

    /**
     * Process form submission after captcha validation
     */
    function processSubmission(form, fieldValues, file, captchaToken) {
        if (file) {
            // Validate file first
            var validation = validateFile(file);
            if (!validation.valid) {
                setLoading(false);
                showError(validation.error);
                return;
            }

            // Compress if image, then upload
            compressImageIfNeeded(file)
                .then(function(processedFile) {
                    // Determine the correct filename (update extension if converted to JPEG)
                    var fileName = file.name;
                    if (processedFile !== file && processedFile.type === 'image/jpeg') {
                        fileName = fileName.replace(/\.(heic|heif|png|webp|bmp)$/i, '.jpg');
                    }

                    // Check if processed file needs chunked upload
                    if (processedFile.size > CHUNK_SIZE) {
                        console.log('CaseForm: Large file detected (' + Math.round(processedFile.size / 1024) + 'KB), using chunked upload');
                        // For large files: submit form first (without file), then upload chunks
                        submitFormThenUploadChunks(fieldValues, processedFile, fileName, captchaToken);
                    } else {
                        // Small file: use original single-request method
                        readFileAsBase64(processedFile, function(base64Content) {
                            submitToSalesforce(fieldValues, fileName, base64Content, captchaToken);
                        }, function(error) {
                            setLoading(false);
                            showError('Error reading file: ' + error);
                        });
                    }
                })
                .catch(function(error) {
                    setLoading(false);
                    showError('Error processing file: ' + error.message);
                });
        } else {
            submitToSalesforce(fieldValues, '', '', captchaToken);
        }
    }

    /**
     * Generate a UUID for upload session tracking
     */
    function generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.random() * 16 | 0;
            var v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    /**
     * Submit form without file, then upload file in chunks
     * @param {Object} fieldValues - Form field values
     * @param {File|Blob} file - The file to upload (may be compressed)
     * @param {string} fileName - The filename to use (may have updated extension)
     * @param {string} captchaToken - reCAPTCHA token
     */
    function submitFormThenUploadChunks(fieldValues, file, fileName, captchaToken) {
        console.log('CaseForm: Submitting form data first (without file)...');

        // First, submit the form without the file to create the Case
        Visualforce.remoting.Manager.invokeAction(
            formConfig.remoteAction,
            formConfig.formId,
            fieldValues,
            '', // No file name
            '', // No file content
            captchaToken || '',
            function(result, event) {
                if (event.status && result && result.success) {
                    var caseNumber = result.caseNumber;
                    console.log('CaseForm: Case created:', caseNumber, '- now uploading file in chunks');

                    // Get the Case ID by querying (we need it for file attachment)
                    // The result contains caseNumber, we need to get caseId
                    // Actually, we need to modify the controller to return caseId too
                    // For now, let's use a workaround: query for the case
                    // Better approach: modify submitForm to return caseId

                    // We'll need to get the caseId - let's add it to the response
                    if (result.caseId) {
                        uploadFileInChunks(result.caseId, file, fileName, caseNumber);
                    } else {
                        // Fallback: show success but note file wasn't attached
                        console.warn('CaseForm: Case created but caseId not returned, cannot attach file');
                        setLoading(false);
                        showSuccess(caseNumber);
                        showError('Note: File could not be attached due to size limits.');
                    }
                } else {
                    setLoading(false);
                    var errorMsg = result && result.error ? result.error : 'Failed to submit form.';
                    console.error('CaseForm: Form submission failed -', errorMsg);
                    showError(errorMsg);
                    if (formConfig.enableCaptcha) {
                        resetCaptcha();
                    }
                }
            },
            { escape: false, timeout: 120000 }
        );
    }

    /**
     * Upload file in chunks
     * @param {string} caseId - The Salesforce Case ID
     * @param {File|Blob} file - The file to upload
     * @param {string} fileName - The filename to use
     * @param {string} caseNumber - The Case number for display
     */
    function uploadFileInChunks(caseId, file, fileName, caseNumber) {
        var uploadKey = generateUUID();
        var totalChunks = Math.ceil(file.size / CHUNK_SIZE);

        console.log('CaseForm: Starting chunked upload - ' + totalChunks + ' chunks, uploadKey:', uploadKey);

        // Read file as ArrayBuffer for chunking
        var reader = new FileReader();
        reader.onload = function(e) {
            var arrayBuffer = e.target.result;
            uploadChunkSequentially(caseId, fileName, arrayBuffer, 0, totalChunks, uploadKey, caseNumber);
        };
        reader.onerror = function() {
            setLoading(false);
            showError('Error reading file for upload.');
        };
        reader.readAsArrayBuffer(file);
    }

    /**
     * Upload chunks one at a time sequentially
     */
    function uploadChunkSequentially(caseId, fileName, arrayBuffer, chunkIndex, totalChunks, uploadKey, caseNumber) {
        // Calculate chunk boundaries
        var start = chunkIndex * CHUNK_SIZE;
        var end = Math.min(start + CHUNK_SIZE, arrayBuffer.byteLength);
        var chunkArrayBuffer = arrayBuffer.slice(start, end);

        // Convert chunk to base64
        var chunkBase64 = arrayBufferToBase64(chunkArrayBuffer);

        console.log('CaseForm: Uploading chunk ' + (chunkIndex + 1) + '/' + totalChunks);

        // Update loading text to show progress
        var submitButton = document.getElementById('submitButton');
        if (submitButton) {
            submitButton.textContent = 'Uploading... ' + Math.round(((chunkIndex + 1) / totalChunks) * 100) + '%';
        }

        Visualforce.remoting.Manager.invokeAction(
            formConfig.uploadChunkAction,
            caseId,
            fileName,
            chunkBase64,
            chunkIndex,
            totalChunks,
            uploadKey,
            function(result, event) {
                if (event.status && result && result.success) {
                    if (result.complete) {
                        // All chunks uploaded and file assembled synchronously
                        console.log('CaseForm: File upload complete');
                        setLoading(false);
                        showSuccess(caseNumber);
                    } else if (result.processing) {
                        // Async assembly in progress - start polling
                        console.log('CaseForm: File assembly queued, polling for completion...');
                        pollUploadStatus(caseId, result.uploadKey, fileName, caseNumber, 0);
                    } else {
                        // Upload next chunk
                        uploadChunkSequentially(caseId, fileName, arrayBuffer, chunkIndex + 1, totalChunks, uploadKey, caseNumber);
                    }
                } else {
                    setLoading(false);
                    var errorMsg = result && result.error ? result.error : 'Failed to upload file chunk.';
                    console.error('CaseForm: Chunk upload failed -', errorMsg);
                    // Show success for case but warn about file
                    showSuccess(caseNumber);
                    showError('Your case was created, but the file could not be attached: ' + errorMsg);
                }
            },
            { escape: false, timeout: 120000 }
        );
    }

    /**
     * Poll for async file assembly completion via VF Remoting
     * Uses exponential backoff: 2s, 3s, 5s, 5s, 5s... up to 60s total
     */
    function pollUploadStatus(caseId, uploadKey, fileName, caseNumber, attempt) {
        var POLL_INTERVALS = [2000, 3000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000];
        var MAX_POLL_TIME = 60000; // 60 seconds total timeout
        var elapsed = 0;
        for (var i = 0; i < attempt; i++) {
            elapsed += (POLL_INTERVALS[i] || 5000);
        }

        if (elapsed >= MAX_POLL_TIME) {
            // Timeout - show success with warning
            console.warn('CaseForm: Upload status polling timed out after 60s');
            setLoading(false);
            showSuccess(caseNumber);
            showError('Your case was created. The file is still being processed and will appear shortly.');
            return;
        }

        var delay = POLL_INTERVALS[attempt] || 5000;

        // Update button text
        var submitButton = document.getElementById('submitButton');
        if (submitButton) {
            submitButton.textContent = 'Processing file...';
        }

        setTimeout(function() {
            Visualforce.remoting.Manager.invokeAction(
                formConfig.checkUploadStatusAction,
                caseId,
                uploadKey,
                fileName,
                function(result, event) {
                    if (event.status && result) {
                        if (result.status === 'complete') {
                            console.log('CaseForm: Async file assembly complete');
                            setLoading(false);
                            showSuccess(caseNumber);
                        } else if (result.status === 'processing') {
                            // Still processing, poll again
                            pollUploadStatus(caseId, uploadKey, fileName, caseNumber, attempt + 1);
                        } else {
                            // Error
                            console.error('CaseForm: Async assembly error -', result.error);
                            setLoading(false);
                            showSuccess(caseNumber);
                            showError('Your case was created, but the file could not be attached: ' + (result.error || 'Processing failed.'));
                        }
                    } else {
                        // Remote action failed - retry
                        console.warn('CaseForm: Status check failed, retrying...');
                        pollUploadStatus(caseId, uploadKey, fileName, caseNumber, attempt + 1);
                    }
                },
                { escape: false, timeout: 30000 }
            );
        }, delay);
    }

    /**
     * Convert ArrayBuffer to Base64 string
     */
    function arrayBufferToBase64(buffer) {
        var binary = '';
        var bytes = new Uint8Array(buffer);
        var len = bytes.byteLength;
        for (var i = 0; i < len; i++) {
            binary += String.fromCharCode(bytes[i]);
        }
        return window.btoa(binary);
    }

    /**
     * Reset reCAPTCHA widget
     */
    function resetCaptcha() {
        if (typeof grecaptcha !== 'undefined') {
            try {
                // Only reset for v2 types (v3 doesn't have a widget to reset)
                var captchaType = formConfig.captchaType || 'V2_Checkbox';
                if (captchaType !== 'V3_Score') {
                    grecaptcha.reset();
                }
            } catch (e) {
                console.error('CaseForm: Error resetting reCAPTCHA:', e);
            }
        }
    }

    /**
     * Show CAPTCHA error message
     */
    function showCaptchaError() {
        var captchaError = document.getElementById('captchaError');
        if (captchaError) {
            captchaError.style.display = 'block';
        }
    }

    /**
     * Hide CAPTCHA error message
     */
    function hideCaptchaError() {
        var captchaError = document.getElementById('captchaError');
        if (captchaError) {
            captchaError.style.display = 'none';
        }
    }

    /**
     * Validate form fields
     * @returns {Array} Array of error messages
     */
    function validateForm(form) {
        var errors = [];
        var inputs = form.querySelectorAll('[data-required="true"]');

        inputs.forEach(function(input) {
            var value = input.value.trim();
            var label = input.getAttribute('data-label') || 'This field';

            if (!value) {
                errors.push(label + ' is required.');
                input.classList.add('error');
            } else {
                // Email validation
                if (input.type === 'email' && !isValidEmail(value)) {
                    errors.push('Please enter a valid email address.');
                    input.classList.add('error');
                }
                input.classList.remove('error');
            }
        });

        return errors;
    }

    /**
     * Simple email validation
     */
    function isValidEmail(email) {
        var re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return re.test(email);
    }

    /**
     * Collect field values from form
     * @returns {Object} Map of field names to values
     */
    function collectFieldValues(form) {
        var values = {};
        var inputs = form.querySelectorAll('input[name], textarea[name]');

        inputs.forEach(function(input) {
            if (input.type !== 'file' && input.name) {
                values[input.name] = input.value.trim();
            }
        });

        return values;
    }

    /**
     * Read file as base64
     */
    function readFileAsBase64(file, onSuccess, onError) {
        var reader = new FileReader();

        reader.onload = function(e) {
            try {
                // Remove data URL prefix (e.g., "data:image/png;base64,")
                var base64 = e.target.result.split(',')[1];
                onSuccess(base64);
            } catch (err) {
                onError(err.message);
            }
        };

        reader.onerror = function() {
            onError('Failed to read file');
        };

        reader.readAsDataURL(file);
    }

    /**
     * Submit form data to Salesforce via Visualforce Remoting
     */
    function submitToSalesforce(fieldValues, fileName, fileContent, captchaToken) {
        console.log('CaseForm: Submitting to Salesforce...');

        // Use Visualforce Remoting with captcha token
        Visualforce.remoting.Manager.invokeAction(
            formConfig.remoteAction,
            formConfig.formId,
            fieldValues,
            fileName,
            fileContent,
            captchaToken || '',
            handleResponse,
            { escape: false, timeout: 120000 }
        );
    }

    /**
     * Handle response from Salesforce
     */
    function handleResponse(result, event) {
        setLoading(false);

        if (event.status) {
            if (result && result.success) {
                console.log('CaseForm: Submission successful, case:', result.caseNumber);
                showSuccess(result.caseNumber);

                if (result.warning) {
                    console.warn('CaseForm: Warning -', result.warning);
                }
            } else {
                var errorMsg = result && result.error ? result.error : 'An unexpected error occurred.';
                console.error('CaseForm: Submission failed -', errorMsg);
                showError(errorMsg);
                // Reset captcha on failure so user can try again
                if (formConfig.enableCaptcha) {
                    resetCaptcha();
                }
            }
        } else {
            console.error('CaseForm: Remote action failed -', event.message);
            showError('Unable to submit form. Please try again later.');
            // Reset captcha on failure
            if (formConfig.enableCaptcha) {
                resetCaptcha();
            }
        }
    }

    /**
     * Show error message
     */
    function showError(message) {
        var errorDiv = document.getElementById('errorMessage');
        if (errorDiv) {
            errorDiv.textContent = message;
            errorDiv.style.display = 'block';
            // Scroll to error
            errorDiv.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }

        // Notify parent in embed mode
        postMessageToParent('error', { error: message });
        setTimeout(notifyResize, 100);
    }

    /**
     * Hide error message
     */
    function hideError() {
        var errorDiv = document.getElementById('errorMessage');
        if (errorDiv) {
            errorDiv.style.display = 'none';
        }
    }

    /**
     * Show success message and hide form
     */
    function showSuccess(caseNumber) {
        var form = document.getElementById('caseForm');
        var successDiv = document.getElementById('successMessage');
        var caseNumberSpan = document.getElementById('caseNumberDisplay');

        if (form) {
            form.style.display = 'none';
        }

        if (caseNumberSpan && caseNumber) {
            caseNumberSpan.textContent = caseNumber;
        }

        if (successDiv) {
            successDiv.style.display = 'block';
            successDiv.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }

        hideError();

        // Notify parent in embed mode
        postMessageToParent('success', { caseNumber: caseNumber });
        setTimeout(notifyResize, 100);
    }

    /**
     * Set loading state
     */
    function setLoading(isLoading) {
        var submitButton = document.getElementById('submitButton');
        if (submitButton) {
            submitButton.disabled = isLoading;
            if (isLoading) {
                submitButton.classList.add('loading');
                submitButton.setAttribute('data-original-text', submitButton.textContent);
                submitButton.textContent = 'Submitting...';
            } else {
                submitButton.classList.remove('loading');
                var originalText = submitButton.getAttribute('data-original-text');
                if (originalText) {
                    submitButton.textContent = originalText;
                }
            }
        }
    }

})();
