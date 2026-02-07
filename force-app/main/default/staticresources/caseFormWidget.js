/**
 * Web-to-Case Embeddable Widget
 * Renders a case submission form with Shadow DOM isolation
 *
 * Usage:
 * <div id="support-form"></div>
 * <script src="https://yoursite.salesforce-sites.com/support/resource/caseFormWidget"></script>
 * <script>
 *   WebToCaseForm.render({
 *     formName: 'support',
 *     containerId: 'support-form',
 *     apiBase: 'https://yoursite.salesforce-sites.com/support/services/apexrest',
 *     onSuccess: function(caseNumber) { console.log('Created:', caseNumber); },
 *     onError: function(error) { console.error('Error:', error); }
 *   });
 * </script>
 */
(function(global) {
    'use strict';

    // Version for cache busting
    var VERSION = '1.0.0';

    // Chunk size for file uploads (750KB raw = ~1MB Base64)
    var CHUNK_SIZE = 750000;

    // Image compression settings
    var TARGET_SIZE_MB = 0.7;
    var MAX_IMAGE_SIZE = 25 * 1024 * 1024; // 25MB for images
    var MAX_DOC_SIZE = 4 * 1024 * 1024;    // 4MB for documents (async assembly supports up to ~4MB)

    // Supported image types for compression
    var SUPPORTED_IMAGE_TYPES = [
        'image/jpeg', 'image/png', 'image/webp', 'image/bmp', 'image/heic', 'image/heif'
    ];

    /**
     * Main widget object
     */
    var WebToCaseForm = {
        VERSION: VERSION,

        /**
         * Render a form widget
         * @param {Object} options Configuration options
         * @param {string} options.formName - Form name/identifier
         * @param {string} options.containerId - ID of container element
         * @param {string} options.apiBase - Base URL for REST API
         * @param {Function} [options.onSuccess] - Success callback (receives caseNumber)
         * @param {Function} [options.onError] - Error callback (receives error message)
         * @param {Function} [options.onLoad] - Called when form is loaded
         */
        render: function(options) {
            if (!options || !options.formName || !options.containerId || !options.apiBase) {
                console.error('WebToCaseForm: Missing required options (formName, containerId, apiBase)');
                return;
            }

            var container = document.getElementById(options.containerId);
            if (!container) {
                console.error('WebToCaseForm: Container not found:', options.containerId);
                return;
            }

            // Create widget instance
            var widget = new FormWidget(container, options);
            widget.init();

            return widget;
        }
    };

    /**
     * FormWidget class - manages a single form instance
     */
    function FormWidget(container, options) {
        this.container = container;
        this.options = options;
        this.formConfig = null;
        this.shadowRoot = null;
        this.captchaWidgetId = null;
        this.captchaResolve = null;
        this.imageCompression = null;
    }

    FormWidget.prototype = {
        /**
         * Initialize the widget
         */
        init: function() {
            var self = this;

            // Create Shadow DOM
            this.shadowRoot = this.container.attachShadow({ mode: 'open' });

            // Show loading state
            this.showLoading();

            // Fetch form configuration
            this.fetchFormConfig()
                .then(function(config) {
                    self.formConfig = config;
                    self.render();
                    self.loadDependencies();
                })
                .catch(function(error) {
                    self.showError('Failed to load form: ' + error);
                    if (self.options.onError) {
                        self.options.onError(error);
                    }
                });
        },

        /**
         * Fetch form configuration from REST API
         */
        fetchFormConfig: function() {
            var self = this;
            var url = this.options.apiBase + '/webtocase/v1/form/' + encodeURIComponent(this.options.formName);

            return fetch(url, {
                method: 'GET',
                headers: {
                    'Accept': 'application/json'
                },
                credentials: 'omit'
            })
            .then(function(response) {
                if (!response.ok) {
                    return response.json().then(function(data) {
                        throw new Error(data.error || 'HTTP ' + response.status);
                    });
                }
                return response.json();
            });
        },

        /**
         * Show loading state
         */
        showLoading: function() {
            this.shadowRoot.innerHTML = this.getStyles() +
                '<div class="wtc-loading"><div class="wtc-spinner"></div><p>Loading form...</p></div>';
        },

        /**
         * Show error state
         */
        showError: function(message) {
            this.shadowRoot.innerHTML = this.getStyles() +
                '<div class="wtc-error"><p>' + this.escapeHtml(message) + '</p></div>';
        },

        /**
         * Render the form
         */
        render: function() {
            var self = this;
            var config = this.formConfig;

            // Build HTML
            var html = this.getStyles();
            html += '<div class="wtc-container">';

            // Header
            if (config.title) {
                html += '<h2 class="wtc-title">' + this.escapeHtml(config.title) + '</h2>';
            }
            if (config.description) {
                html += '<p class="wtc-description">' + this.escapeHtml(config.description) + '</p>';
            }

            // Form
            html += '<form class="wtc-form" id="wtcForm">';

            // Fields
            for (var i = 0; i < config.fields.length; i++) {
                var field = config.fields[i];
                html += this.renderField(field);
            }

            // File upload (if enabled)
            if (config.enableFileUpload) {
                html += '<div class="wtc-field">';
                html += '<label for="wtcFile">Attachment</label>';
                html += '<input type="file" id="wtcFile" class="wtc-file-input" />';
                html += '<span class="wtc-help">Max ' + config.maxFileSizeMB + 'MB. Images are automatically optimized.</span>';
                html += '</div>';
            }

            // CAPTCHA placeholder (rendered in light DOM)
            if (config.enableCaptcha) {
                html += '<div class="wtc-field wtc-captcha-placeholder">';
                html += '<div id="wtcCaptchaContainer"></div>';
                html += '<span class="wtc-captcha-error" id="wtcCaptchaError" style="display:none;">Please complete the verification.</span>';
                html += '</div>';
            }

            // Error message
            html += '<div class="wtc-error-message" id="wtcError" style="display:none;"></div>';

            // Submit button
            html += '<button type="submit" class="wtc-submit" id="wtcSubmit">Submit</button>';

            html += '</form>';

            // Success message (hidden by default)
            html += '<div class="wtc-success" id="wtcSuccess" style="display:none;">';
            html += '<div class="wtc-success-icon">&#10003;</div>';
            html += '<p>' + this.escapeHtml(config.successMessage || 'Your request has been submitted successfully.') + '</p>';
            html += '<p class="wtc-case-number">Reference: <span id="wtcCaseNumber"></span></p>';
            html += '</div>';

            html += '</div>';

            this.shadowRoot.innerHTML = html;

            // Attach event listeners
            this.attachEventListeners();

            // Callback
            if (this.options.onLoad) {
                this.options.onLoad();
            }
        },

        /**
         * Render a single form field
         */
        renderField: function(field) {
            var html = '<div class="wtc-field">';
            var inputId = 'wtcField_' + field.caseField;
            var required = field.required ? ' data-required="true"' : '';
            var requiredMark = field.required ? '<span class="wtc-required">*</span>' : '';

            html += '<label for="' + inputId + '">' + this.escapeHtml(field.label) + requiredMark + '</label>';

            switch (field.type) {
                case 'Textarea':
                    html += '<textarea id="' + inputId + '" name="' + field.caseField + '" class="wtc-input wtc-textarea"' +
                            required + ' data-label="' + this.escapeHtml(field.label) + '"></textarea>';
                    break;
                case 'Email':
                    html += '<input type="email" id="' + inputId + '" name="' + field.caseField + '" class="wtc-input"' +
                            required + ' data-label="' + this.escapeHtml(field.label) + '" />';
                    break;
                case 'Phone':
                    html += '<input type="tel" id="' + inputId + '" name="' + field.caseField + '" class="wtc-input"' +
                            required + ' data-label="' + this.escapeHtml(field.label) + '" />';
                    break;
                default:
                    html += '<input type="text" id="' + inputId + '" name="' + field.caseField + '" class="wtc-input"' +
                            required + ' data-label="' + this.escapeHtml(field.label) + '" />';
            }

            html += '</div>';
            return html;
        },

        /**
         * Attach event listeners
         */
        attachEventListeners: function() {
            var self = this;
            var form = this.shadowRoot.getElementById('wtcForm');

            if (form) {
                form.addEventListener('submit', function(e) {
                    e.preventDefault();
                    self.handleSubmit();
                });
            }

            // Clear error styling on input
            var inputs = this.shadowRoot.querySelectorAll('.wtc-input');
            for (var i = 0; i < inputs.length; i++) {
                inputs[i].addEventListener('input', function() {
                    this.classList.remove('wtc-input-error');
                    self.hideError();
                });
            }
        },

        /**
         * Load external dependencies (CAPTCHA, image compression)
         */
        loadDependencies: function() {
            var self = this;

            // Load image compression if file upload is enabled
            if (this.formConfig.enableFileUpload) {
                this.loadImageCompression();
            }

            // Load reCAPTCHA if enabled
            if (this.formConfig.enableCaptcha && this.formConfig.captchaSiteKey) {
                this.loadCaptcha();
            }
        },

        /**
         * Load image compression library
         */
        loadImageCompression: function() {
            var self = this;

            // Check if already loaded
            if (typeof imageCompression !== 'undefined') {
                this.imageCompression = imageCompression;
                return;
            }

            // Load from CDN
            var script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/browser-image-compression@2.0.2/dist/browser-image-compression.js';
            script.onload = function() {
                self.imageCompression = imageCompression;
            };
            document.head.appendChild(script);
        },

        /**
         * Load reCAPTCHA
         * Note: CAPTCHA must be rendered in light DOM due to callback issues with Shadow DOM
         */
        loadCaptcha: function() {
            var self = this;
            var config = this.formConfig;
            var captchaType = config.captchaType || 'V2_Checkbox';

            // Create container in light DOM (outside Shadow DOM)
            var lightContainer = document.createElement('div');
            lightContainer.id = 'wtc_captcha_' + Date.now();
            lightContainer.style.marginBottom = '16px';

            // Find placeholder in shadow DOM and insert light DOM element after container
            var placeholder = this.shadowRoot.getElementById('wtcCaptchaContainer');
            if (placeholder) {
                // Insert after the widget container in light DOM
                this.container.appendChild(lightContainer);
            }

            // Store reference
            this.captchaLightContainer = lightContainer;

            // Load reCAPTCHA script
            var scriptUrl = captchaType === 'V3_Score'
                ? 'https://www.google.com/recaptcha/api.js?render=' + config.captchaSiteKey
                : 'https://www.google.com/recaptcha/api.js?onload=wtcCaptchaOnload&render=explicit';

            // Setup global callback for v2
            if (captchaType !== 'V3_Score') {
                window.wtcCaptchaOnload = function() {
                    self.renderCaptchaWidget();
                };

                // Global callback for invisible captcha
                window.wtcCaptchaSuccess = function(token) {
                    if (self.captchaResolve) {
                        self.captchaResolve(token);
                        self.captchaResolve = null;
                    }
                };
            }

            var script = document.createElement('script');
            script.src = scriptUrl;
            script.async = true;
            script.defer = true;
            document.head.appendChild(script);
        },

        /**
         * Render CAPTCHA widget (for v2 types)
         */
        renderCaptchaWidget: function() {
            var config = this.formConfig;
            var captchaType = config.captchaType || 'V2_Checkbox';

            if (!this.captchaLightContainer || typeof grecaptcha === 'undefined') {
                return;
            }

            var params = {
                sitekey: config.captchaSiteKey
            };

            if (captchaType === 'V2_Invisible') {
                params.size = 'invisible';
                params.callback = 'wtcCaptchaSuccess';
            }

            this.captchaWidgetId = grecaptcha.render(this.captchaLightContainer.id, params);
        },

        /**
         * Get CAPTCHA token
         */
        getCaptchaToken: function() {
            var self = this;
            var config = this.formConfig;

            return new Promise(function(resolve, reject) {
                if (!config.enableCaptcha) {
                    resolve('');
                    return;
                }

                var captchaType = config.captchaType || 'V2_Checkbox';

                if (captchaType === 'V3_Score') {
                    if (typeof grecaptcha === 'undefined') {
                        reject(new Error('reCAPTCHA not loaded'));
                        return;
                    }
                    grecaptcha.ready(function() {
                        grecaptcha.execute(config.captchaSiteKey, { action: 'submit' })
                            .then(resolve)
                            .catch(reject);
                    });
                } else if (captchaType === 'V2_Invisible') {
                    if (typeof grecaptcha === 'undefined') {
                        reject(new Error('reCAPTCHA not loaded'));
                        return;
                    }
                    self.captchaResolve = resolve;
                    grecaptcha.execute(self.captchaWidgetId);
                } else {
                    // V2_Checkbox
                    if (typeof grecaptcha !== 'undefined' && self.captchaWidgetId !== null) {
                        var token = grecaptcha.getResponse(self.captchaWidgetId);
                        resolve(token);
                    } else {
                        resolve('');
                    }
                }
            });
        },

        /**
         * Reset CAPTCHA
         */
        resetCaptcha: function() {
            if (typeof grecaptcha !== 'undefined' && this.captchaWidgetId !== null) {
                var captchaType = this.formConfig.captchaType || 'V2_Checkbox';
                if (captchaType !== 'V3_Score') {
                    grecaptcha.reset(this.captchaWidgetId);
                }
            }
        },

        /**
         * Refresh nonce after a failed submission
         * Nonces are one-time use, so we need a fresh one after any submission attempt
         */
        refreshNonce: function() {
            var self = this;
            this.fetchFormConfig()
                .then(function(config) {
                    // Update only the nonce, preserve other state
                    self.formConfig.nonce = config.nonce;
                })
                .catch(function(error) {
                    // Log error but don't disrupt user experience
                    console.warn('Failed to refresh nonce:', error);
                });
        },

        /**
         * Handle form submission
         */
        handleSubmit: function() {
            var self = this;
            var config = this.formConfig;

            // Validate form
            var errors = this.validateForm();
            if (errors.length > 0) {
                this.showFormError(errors.join('<br>'));
                return;
            }

            // Validate CAPTCHA (for v2 checkbox)
            var captchaType = config.captchaType || 'V2_Checkbox';
            if (config.enableCaptcha && captchaType === 'V2_Checkbox') {
                if (typeof grecaptcha !== 'undefined' && this.captchaWidgetId !== null) {
                    var token = grecaptcha.getResponse(this.captchaWidgetId);
                    if (!token) {
                        this.showCaptchaError();
                        this.showFormError('Please complete the verification.');
                        return;
                    }
                    this.hideCaptchaError();
                }
            }

            // Collect field values
            var fieldValues = this.collectFieldValues();

            // Get file
            var fileInput = this.shadowRoot.getElementById('wtcFile');
            var file = fileInput && fileInput.files.length > 0 ? fileInput.files[0] : null;

            // Validate file
            if (file) {
                var fileValidation = this.validateFile(file);
                if (!fileValidation.valid) {
                    this.showFormError(fileValidation.error);
                    return;
                }
            }

            this.setLoading(true);

            // Get CAPTCHA token and submit
            this.getCaptchaToken()
                .then(function(captchaToken) {
                    if (config.enableCaptcha && captchaType === 'V2_Invisible' && !captchaToken) {
                        self.setLoading(false);
                        self.showCaptchaError();
                        self.showFormError('Verification failed. Please try again.');
                        return;
                    }
                    self.processSubmission(fieldValues, file, captchaToken);
                })
                .catch(function(err) {
                    self.setLoading(false);
                    self.showFormError('Verification error. Please try again.');
                    console.error('WebToCaseForm: CAPTCHA error:', err);
                });
        },

        /**
         * Process form submission
         */
        processSubmission: function(fieldValues, file, captchaToken) {
            var self = this;

            if (file) {
                // Compress image if needed, then submit
                this.compressImageIfNeeded(file)
                    .then(function(processedFile) {
                        var fileName = file.name;
                        // Update extension if converted to JPEG
                        if (processedFile !== file && processedFile.type === 'image/jpeg') {
                            fileName = fileName.replace(/\.(heic|heif|png|webp|bmp)$/i, '.jpg');
                        }

                        if (processedFile.size > CHUNK_SIZE) {
                            // Large file: submit form first, then upload chunks
                            self.submitFormThenUploadChunks(fieldValues, processedFile, fileName, captchaToken);
                        } else {
                            // Small file: single request
                            self.readFileAsBase64(processedFile)
                                .then(function(base64) {
                                    self.submitForm(fieldValues, fileName, base64, captchaToken);
                                })
                                .catch(function(err) {
                                    self.setLoading(false);
                                    self.showFormError('Error reading file.');
                                });
                        }
                    })
                    .catch(function(err) {
                        self.setLoading(false);
                        self.showFormError('Error processing file.');
                    });
            } else {
                this.submitForm(fieldValues, '', '', captchaToken);
            }
        },

        /**
         * Submit form to REST API
         */
        submitForm: function(fieldValues, fileName, fileContent, captchaToken) {
            var self = this;
            var config = this.formConfig;
            var url = this.options.apiBase + '/webtocase/v1/submit';

            fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                credentials: 'omit',
                body: JSON.stringify({
                    formId: config.formId,
                    nonce: config.nonce,
                    fieldValues: fieldValues,
                    fileName: fileName,
                    fileContent: fileContent,
                    captchaToken: captchaToken
                })
            })
            .then(function(response) {
                return response.json().then(function(data) {
                    return { status: response.status, data: data };
                });
            })
            .then(function(result) {
                self.setLoading(false);

                if (result.data.success) {
                    self.showSuccess(result.data.caseNumber);
                    if (self.options.onSuccess) {
                        self.options.onSuccess(result.data.caseNumber);
                    }
                } else {
                    var errorMsg = result.data.error || 'Submission failed.';
                    self.showFormError(errorMsg);
                    self.resetCaptcha();
                    self.refreshNonce(); // Get new nonce for retry
                    if (self.options.onError) {
                        self.options.onError(errorMsg);
                    }
                }
            })
            .catch(function(err) {
                self.setLoading(false);
                self.showFormError('Network error. Please try again.');
                self.resetCaptcha();
                self.refreshNonce(); // Get new nonce for retry
                if (self.options.onError) {
                    self.options.onError(err.message);
                }
            });
        },

        /**
         * Submit form then upload file in chunks
         */
        submitFormThenUploadChunks: function(fieldValues, file, fileName, captchaToken) {
            var self = this;
            var config = this.formConfig;
            var url = this.options.apiBase + '/webtocase/v1/submit';

            // Submit form without file first
            fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                credentials: 'omit',
                body: JSON.stringify({
                    formId: config.formId,
                    nonce: config.nonce,
                    fieldValues: fieldValues,
                    fileName: '',
                    fileContent: '',
                    captchaToken: captchaToken
                })
            })
            .then(function(response) {
                return response.json();
            })
            .then(function(result) {
                if (result.success && result.caseId) {
                    self.uploadFileInChunks(result.caseId, file, fileName, result.caseNumber, config.formId);
                } else if (result.success) {
                    // Case created but no caseId for file upload
                    self.setLoading(false);
                    self.showSuccess(result.caseNumber);
                    self.showFormError('Note: File could not be attached.');
                    if (self.options.onSuccess) {
                        self.options.onSuccess(result.caseNumber);
                    }
                } else {
                    self.setLoading(false);
                    self.showFormError(result.error || 'Submission failed.');
                    self.resetCaptcha();
                    self.refreshNonce(); // Get new nonce for retry
                }
            })
            .catch(function(err) {
                self.setLoading(false);
                self.showFormError('Network error. Please try again.');
                self.resetCaptcha();
                self.refreshNonce(); // Get new nonce for retry
            });
        },

        /**
         * Upload file in chunks
         */
        uploadFileInChunks: function(caseId, file, fileName, caseNumber, formId) {
            var self = this;
            var uploadKey = this.generateUUID();
            var totalChunks = Math.ceil(file.size / CHUNK_SIZE);

            var reader = new FileReader();
            reader.onload = function(e) {
                var arrayBuffer = e.target.result;
                self.uploadChunkSequentially(caseId, fileName, arrayBuffer, 0, totalChunks, uploadKey, caseNumber, formId);
            };
            reader.onerror = function() {
                self.setLoading(false);
                self.showSuccess(caseNumber);
                self.showFormError('File could not be uploaded.');
            };
            reader.readAsArrayBuffer(file);
        },

        /**
         * Upload chunks sequentially
         */
        uploadChunkSequentially: function(caseId, fileName, arrayBuffer, chunkIndex, totalChunks, uploadKey, caseNumber, formId) {
            var self = this;
            var url = this.options.apiBase + '/webtocase/v1/upload-chunk';

            var start = chunkIndex * CHUNK_SIZE;
            var end = Math.min(start + CHUNK_SIZE, arrayBuffer.byteLength);
            var chunkArrayBuffer = arrayBuffer.slice(start, end);
            var chunkBase64 = this.arrayBufferToBase64(chunkArrayBuffer);

            // Update progress
            this.updateButtonText('Uploading... ' + Math.round(((chunkIndex + 1) / totalChunks) * 100) + '%');

            fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                credentials: 'omit',
                body: JSON.stringify({
                    caseId: caseId,
                    fileName: fileName,
                    chunkData: chunkBase64,
                    chunkIndex: chunkIndex,
                    totalChunks: totalChunks,
                    uploadKey: uploadKey,
                    formId: formId
                })
            })
            .then(function(response) {
                return response.json();
            })
            .then(function(result) {
                if (result.success) {
                    if (result.complete) {
                        self.setLoading(false);
                        self.showSuccess(caseNumber);
                        if (self.options.onSuccess) {
                            self.options.onSuccess(caseNumber);
                        }
                    } else if (result.processing) {
                        // Async assembly in progress - start polling
                        self.pollUploadStatus(caseId, result.uploadKey, fileName, caseNumber, formId, 0);
                    } else {
                        // Upload next chunk
                        self.uploadChunkSequentially(caseId, fileName, arrayBuffer, chunkIndex + 1, totalChunks, uploadKey, caseNumber, formId);
                    }
                } else {
                    self.setLoading(false);
                    self.showSuccess(caseNumber);
                    self.showFormError('File upload failed: ' + (result.error || 'Unknown error'));
                }
            })
            .catch(function(err) {
                self.setLoading(false);
                self.showSuccess(caseNumber);
                self.showFormError('File upload failed.');
            });
        },

        /**
         * Poll for async file assembly completion via REST API
         * Uses exponential backoff: 2s, 3s, 5s, 5s, 5s... up to 60s total
         */
        pollUploadStatus: function(caseId, uploadKey, fileName, caseNumber, formId, attempt) {
            var self = this;
            var POLL_INTERVALS = [2000, 3000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000, 5000];
            var MAX_POLL_TIME = 60000;
            var elapsed = 0;
            for (var i = 0; i < attempt; i++) {
                elapsed += (POLL_INTERVALS[i] || 5000);
            }

            if (elapsed >= MAX_POLL_TIME) {
                self.setLoading(false);
                self.showSuccess(caseNumber);
                self.showFormError('Your case was created. The file is still being processed and will appear shortly.');
                if (self.options.onSuccess) {
                    self.options.onSuccess(caseNumber);
                }
                return;
            }

            var delay = POLL_INTERVALS[attempt] || 5000;
            self.updateButtonText('Processing file...');

            setTimeout(function() {
                var url = self.options.apiBase + '/webtocase/v1/upload-status';

                fetch(url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Accept': 'application/json'
                    },
                    credentials: 'omit',
                    body: JSON.stringify({
                        caseId: caseId,
                        uploadKey: uploadKey,
                        fileName: fileName,
                        formId: formId
                    })
                })
                .then(function(response) {
                    return response.json();
                })
                .then(function(result) {
                    if (result.status === 'complete') {
                        self.setLoading(false);
                        self.showSuccess(caseNumber);
                        if (self.options.onSuccess) {
                            self.options.onSuccess(caseNumber);
                        }
                    } else if (result.status === 'processing') {
                        self.pollUploadStatus(caseId, uploadKey, fileName, caseNumber, formId, attempt + 1);
                    } else {
                        self.setLoading(false);
                        self.showSuccess(caseNumber);
                        self.showFormError('Your case was created, but the file could not be attached: ' + (result.error || 'Processing failed.'));
                    }
                })
                .catch(function() {
                    // Network error - retry
                    self.pollUploadStatus(caseId, uploadKey, fileName, caseNumber, formId, attempt + 1);
                });
            }, delay);
        },

        /**
         * Validate form fields
         */
        validateForm: function() {
            var errors = [];
            var inputs = this.shadowRoot.querySelectorAll('[data-required="true"]');

            for (var i = 0; i < inputs.length; i++) {
                var input = inputs[i];
                var value = input.value.trim();
                var label = input.getAttribute('data-label') || 'This field';

                if (!value) {
                    errors.push(label + ' is required.');
                    input.classList.add('wtc-input-error');
                } else if (input.type === 'email' && !this.isValidEmail(value)) {
                    errors.push('Please enter a valid email address.');
                    input.classList.add('wtc-input-error');
                } else {
                    input.classList.remove('wtc-input-error');
                }
            }

            return errors;
        },

        /**
         * Validate file
         */
        validateFile: function(file) {
            // Videos not supported
            if (file.type && file.type.startsWith('video/')) {
                return { valid: false, error: 'Video files are not supported.' };
            }

            var isImage = this.isSupportedImage(file);

            if (isImage && file.size > MAX_IMAGE_SIZE) {
                return { valid: false, error: 'Image too large. Max 25MB.' };
            }

            if (!isImage && file.size > MAX_DOC_SIZE) {
                return { valid: false, error: 'File too large. Documents max 4MB.' };
            }

            return { valid: true };
        },

        /**
         * Check if file is a supported image
         */
        isSupportedImage: function(file) {
            if (SUPPORTED_IMAGE_TYPES.indexOf(file.type) !== -1) {
                return true;
            }
            var fileName = file.name.toLowerCase();
            return /\.(jpg|jpeg|png|webp|bmp|heic|heif)$/.test(fileName);
        },

        /**
         * Compress image if needed
         */
        compressImageIfNeeded: function(file) {
            var self = this;

            return new Promise(function(resolve) {
                if (!self.isSupportedImage(file)) {
                    resolve(file);
                    return;
                }

                var targetBytes = TARGET_SIZE_MB * 1024 * 1024;
                if (file.size <= targetBytes) {
                    resolve(file);
                    return;
                }

                if (!self.imageCompression) {
                    resolve(file);
                    return;
                }

                self.updateButtonText('Optimizing image...');

                var options = {
                    maxSizeMB: TARGET_SIZE_MB,
                    maxWidthOrHeight: 2560,
                    useWebWorker: true,
                    initialQuality: 0.85,
                    preserveExif: false,
                    fileType: 'image/jpeg',
                    onProgress: function(progress) {
                        self.updateButtonText('Optimizing... ' + Math.round(progress) + '%');
                    }
                };

                self.imageCompression(file, options)
                    .then(resolve)
                    .catch(function() {
                        resolve(file);
                    });
            });
        },

        /**
         * Collect field values
         */
        collectFieldValues: function() {
            var values = {};
            var inputs = this.shadowRoot.querySelectorAll('input[name], textarea[name]');

            for (var i = 0; i < inputs.length; i++) {
                var input = inputs[i];
                if (input.type !== 'file' && input.name) {
                    values[input.name] = input.value.trim();
                }
            }

            return values;
        },

        /**
         * Read file as Base64
         */
        readFileAsBase64: function(file) {
            return new Promise(function(resolve, reject) {
                var reader = new FileReader();
                reader.onload = function(e) {
                    var base64 = e.target.result.split(',')[1];
                    resolve(base64);
                };
                reader.onerror = function() {
                    reject(new Error('Failed to read file'));
                };
                reader.readAsDataURL(file);
            });
        },

        /**
         * Convert ArrayBuffer to Base64
         */
        arrayBufferToBase64: function(buffer) {
            var binary = '';
            var bytes = new Uint8Array(buffer);
            for (var i = 0; i < bytes.byteLength; i++) {
                binary += String.fromCharCode(bytes[i]);
            }
            return window.btoa(binary);
        },

        /**
         * Generate UUID
         */
        generateUUID: function() {
            return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                var r = Math.random() * 16 | 0;
                var v = c === 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
        },

        /**
         * Email validation
         */
        isValidEmail: function(email) {
            return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
        },

        /**
         * Set loading state
         */
        setLoading: function(loading) {
            var button = this.shadowRoot.getElementById('wtcSubmit');
            if (button) {
                button.disabled = loading;
                if (loading) {
                    button.classList.add('wtc-loading');
                    button.setAttribute('data-original-text', button.textContent);
                    button.textContent = 'Submitting...';
                } else {
                    button.classList.remove('wtc-loading');
                    var originalText = button.getAttribute('data-original-text');
                    if (originalText) {
                        button.textContent = originalText;
                    }
                }
            }
        },

        /**
         * Update button text
         */
        updateButtonText: function(text) {
            var button = this.shadowRoot.getElementById('wtcSubmit');
            if (button) {
                button.textContent = text;
            }
        },

        /**
         * Show form error
         */
        showFormError: function(message) {
            var errorDiv = this.shadowRoot.getElementById('wtcError');
            if (errorDiv) {
                errorDiv.innerHTML = message;
                errorDiv.style.display = 'block';
            }
        },

        /**
         * Hide error
         */
        hideError: function() {
            var errorDiv = this.shadowRoot.getElementById('wtcError');
            if (errorDiv) {
                errorDiv.style.display = 'none';
            }
        },

        /**
         * Show CAPTCHA error
         */
        showCaptchaError: function() {
            var errorSpan = this.shadowRoot.getElementById('wtcCaptchaError');
            if (errorSpan) {
                errorSpan.style.display = 'block';
            }
        },

        /**
         * Hide CAPTCHA error
         */
        hideCaptchaError: function() {
            var errorSpan = this.shadowRoot.getElementById('wtcCaptchaError');
            if (errorSpan) {
                errorSpan.style.display = 'none';
            }
        },

        /**
         * Show success message
         */
        showSuccess: function(caseNumber) {
            var form = this.shadowRoot.getElementById('wtcForm');
            var success = this.shadowRoot.getElementById('wtcSuccess');
            var caseSpan = this.shadowRoot.getElementById('wtcCaseNumber');

            if (form) form.style.display = 'none';
            if (caseSpan) caseSpan.textContent = caseNumber;
            if (success) success.style.display = 'block';

            // Hide CAPTCHA container in light DOM
            if (this.captchaLightContainer) {
                this.captchaLightContainer.style.display = 'none';
            }

            this.hideError();
        },

        /**
         * Escape HTML
         */
        escapeHtml: function(str) {
            if (!str) return '';
            return String(str)
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
        },

        /**
         * Get widget styles (with CSS variable support)
         */
        getStyles: function() {
            return '<style>' +
                ':host {' +
                '  --wtc-primary-color: var(--wtc-primary-color, #0176d3);' +
                '  --wtc-font-family: var(--wtc-font-family, system-ui, -apple-system, sans-serif);' +
                '  --wtc-border-radius: var(--wtc-border-radius, 4px);' +
                '  --wtc-input-border: var(--wtc-input-border, 1px solid #c9c9c9);' +
                '  --wtc-input-background: var(--wtc-input-background, #ffffff);' +
                '  --wtc-text-color: var(--wtc-text-color, #181818);' +
                '  --wtc-error-color: var(--wtc-error-color, #c23934);' +
                '  --wtc-success-color: var(--wtc-success-color, #2e844a);' +
                '  display: block;' +
                '  font-family: var(--wtc-font-family);' +
                '  color: var(--wtc-text-color);' +
                '  line-height: 1.5;' +
                '}' +

                '.wtc-container {' +
                '  max-width: 100%;' +
                '}' +

                '.wtc-title {' +
                '  font-size: 1.5rem;' +
                '  font-weight: 600;' +
                '  margin: 0 0 8px 0;' +
                '  color: var(--wtc-text-color);' +
                '}' +

                '.wtc-description {' +
                '  font-size: 0.875rem;' +
                '  color: #666;' +
                '  margin: 0 0 24px 0;' +
                '}' +

                '.wtc-form {' +
                '  display: flex;' +
                '  flex-direction: column;' +
                '  gap: 20px;' +
                '}' +

                '.wtc-field {' +
                '  display: flex;' +
                '  flex-direction: column;' +
                '}' +

                '.wtc-field label {' +
                '  font-size: 0.875rem;' +
                '  font-weight: 500;' +
                '  margin-bottom: 6px;' +
                '  color: var(--wtc-text-color);' +
                '}' +

                '.wtc-required {' +
                '  color: var(--wtc-error-color);' +
                '  margin-left: 2px;' +
                '}' +

                '.wtc-input {' +
                '  width: 100%;' +
                '  padding: 10px 12px;' +
                '  font-size: 1rem;' +
                '  font-family: inherit;' +
                '  color: var(--wtc-text-color);' +
                '  background: var(--wtc-input-background);' +
                '  border: var(--wtc-input-border);' +
                '  border-radius: var(--wtc-border-radius);' +
                '  transition: border-color 0.2s, box-shadow 0.2s;' +
                '}' +

                '.wtc-input:focus {' +
                '  outline: none;' +
                '  border-color: var(--wtc-primary-color);' +
                '  box-shadow: 0 0 0 3px rgba(1, 118, 211, 0.15);' +
                '}' +

                '.wtc-input-error {' +
                '  border-color: var(--wtc-error-color) !important;' +
                '  box-shadow: 0 0 0 3px rgba(194, 57, 52, 0.15) !important;' +
                '}' +

                '.wtc-textarea {' +
                '  resize: vertical;' +
                '  min-height: 100px;' +
                '}' +

                '.wtc-file-input {' +
                '  padding: 8px;' +
                '  background: #f9f9f9;' +
                '  border: var(--wtc-input-border);' +
                '  border-radius: var(--wtc-border-radius);' +
                '  cursor: pointer;' +
                '}' +

                '.wtc-help {' +
                '  font-size: 0.75rem;' +
                '  color: #666;' +
                '  margin-top: 4px;' +
                '}' +

                '.wtc-submit {' +
                '  width: 100%;' +
                '  padding: 12px 24px;' +
                '  font-size: 1rem;' +
                '  font-weight: 600;' +
                '  font-family: inherit;' +
                '  color: #fff;' +
                '  background: var(--wtc-primary-color);' +
                '  border: none;' +
                '  border-radius: var(--wtc-border-radius);' +
                '  cursor: pointer;' +
                '  transition: background-color 0.2s, opacity 0.2s;' +
                '}' +

                '.wtc-submit:hover:not(:disabled) {' +
                '  opacity: 0.9;' +
                '}' +

                '.wtc-submit:disabled {' +
                '  background: #9ca3af;' +
                '  cursor: not-allowed;' +
                '}' +

                '.wtc-submit.wtc-loading {' +
                '  position: relative;' +
                '}' +

                '.wtc-error-message {' +
                '  padding: 12px 16px;' +
                '  font-size: 0.875rem;' +
                '  color: #721c24;' +
                '  background: #f8d7da;' +
                '  border: 1px solid #f5c6cb;' +
                '  border-radius: var(--wtc-border-radius);' +
                '}' +

                '.wtc-captcha-error {' +
                '  font-size: 0.75rem;' +
                '  color: var(--wtc-error-color);' +
                '  margin-top: 8px;' +
                '}' +

                '.wtc-success {' +
                '  padding: 24px;' +
                '  text-align: center;' +
                '  color: var(--wtc-success-color);' +
                '  background: #d4edda;' +
                '  border: 1px solid #c3e6cb;' +
                '  border-radius: var(--wtc-border-radius);' +
                '}' +

                '.wtc-success-icon {' +
                '  font-size: 2.5rem;' +
                '  margin-bottom: 12px;' +
                '}' +

                '.wtc-success p {' +
                '  margin: 8px 0;' +
                '}' +

                '.wtc-case-number {' +
                '  font-size: 0.875rem;' +
                '  color: #0d5c3d;' +
                '}' +

                '.wtc-case-number span {' +
                '  font-weight: 600;' +
                '}' +

                '.wtc-loading {' +
                '  display: flex;' +
                '  flex-direction: column;' +
                '  align-items: center;' +
                '  justify-content: center;' +
                '  padding: 40px;' +
                '  color: #666;' +
                '}' +

                '.wtc-spinner {' +
                '  width: 32px;' +
                '  height: 32px;' +
                '  border: 3px solid #e5e5e5;' +
                '  border-top-color: var(--wtc-primary-color);' +
                '  border-radius: 50%;' +
                '  animation: wtc-spin 0.8s linear infinite;' +
                '  margin-bottom: 12px;' +
                '}' +

                '@keyframes wtc-spin {' +
                '  to { transform: rotate(360deg); }' +
                '}' +

                '.wtc-error {' +
                '  padding: 24px;' +
                '  text-align: center;' +
                '  color: var(--wtc-error-color);' +
                '  background: #fef2f2;' +
                '  border: 1px solid #fecaca;' +
                '  border-radius: var(--wtc-border-radius);' +
                '}' +
            '</style>';
        }
    };

    // Export to global scope
    global.WebToCaseForm = WebToCaseForm;

})(typeof window !== 'undefined' ? window : this);
