/* global grecaptcha, imageCompression */
/* eslint @lwc/lwc/no-inner-html: "off", no-prototype-builtins: "off" */
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
            var lightContainer = this.captchaLightContainer;

            // Connected mode: use user-provided container by ID
            if (!lightContainer && this.options && this.options.captchaContainerId) {
                lightContainer = document.getElementById(this.options.captchaContainerId);
            }

            // Widget mode: create and inject a light DOM container (outside Shadow DOM)
            if (!lightContainer && this.shadowRoot && this.container) {
                lightContainer = document.createElement('div');
                lightContainer.style.marginBottom = '16px';
                this.container.appendChild(lightContainer);
            }

            // v2 modes require a visible container
            if (captchaType !== 'V3_Score' && !lightContainer) {
                console.warn(
                    'WebToCaseForm: CAPTCHA container not found. ' +
                    'Provide captchaContainerId when using connect().'
                );
                return;
            }

            if (lightContainer) {
                if (!lightContainer.id) {
                    lightContainer.id = 'wtc_captcha_' + Date.now() + '_' + Math.floor(Math.random() * 10000);
                }
                lightContainer.style.display = '';
            }

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

            // If already loaded, render immediately for v2.
            if (typeof grecaptcha !== 'undefined') {
                if (captchaType !== 'V3_Score') {
                    this.renderCaptchaWidget();
                }
                return;
            }

            // Prevent duplicate script tags across multiple form instances.
            if (document.querySelector('script[data-wtc-recaptcha="true"]')) {
                return;
            }

            var script = document.createElement('script');
            script.src = scriptUrl;
            script.async = true;
            script.defer = true;
            script.setAttribute('data-wtc-recaptcha', 'true');
            document.head.appendChild(script);
        },

        /**
         * Render CAPTCHA widget (for v2 types)
         */
        renderCaptchaWidget: function() {
            var config = this.formConfig;
            var captchaType = config.captchaType || 'V2_Checkbox';

            if (!this.captchaLightContainer || typeof grecaptcha === 'undefined' || this.captchaWidgetId !== null) {
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
                                .catch(function() {
                                    self.setLoading(false);
                                    self.showFormError('Error reading file.');
                                });
                        }
                    })
                    .catch(function() {
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
        submitForm: function(fieldValues, fileName, fileContent, captchaToken, _isRetry) {
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
                if (result.data.success) {
                    self.setLoading(false);
                    self.showSuccess(result.data.caseNumber);
                    if (self.options.onSuccess) {
                        self.options.onSuccess(result.data.caseNumber);
                    }
                } else {
                    var errorMsg = result.data.error || 'Submission failed.';

                    // Transparent nonce retry: fetch fresh config and resubmit once
                    if (!_isRetry && errorMsg.toLowerCase().indexOf('nonce') !== -1) {
                        self.fetchFormConfig()
                            .then(function(freshConfig) {
                                self.formConfig = freshConfig;
                                self.submitForm(fieldValues, fileName, fileContent, captchaToken, true);
                            })
                            .catch(function() {
                                self.setLoading(false);
                                self.showFormError(errorMsg);
                                self.resetCaptcha();
                            });
                        return;
                    }

                    self.setLoading(false);
                    self.showFormError(errorMsg);
                    self.resetCaptcha();
                    self.refreshNonce(); // Get new nonce for manual retry
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
            .catch(function() {
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
            .catch(function() {
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
                '  display: block;' +
                '  font-family: var(--wtc-font-family, system-ui, -apple-system, sans-serif);' +
                '  color: var(--wtc-text-color, #181818);' +
                '  line-height: 1.5;' +
                '}' +

                '.wtc-container {' +
                '  max-width: var(--wtc-container-max-width, 100%);' +
                '  padding: var(--wtc-container-padding, 0);' +
                '}' +

                '.wtc-title {' +
                '  font-size: var(--wtc-title-font-size, 1.5rem);' +
                '  font-weight: var(--wtc-title-font-weight, 600);' +
                '  margin: var(--wtc-title-margin, 0 0 8px 0);' +
                '  color: var(--wtc-text-color, #181818);' +
                '}' +

                '.wtc-description {' +
                '  font-size: var(--wtc-description-font-size, 0.875rem);' +
                '  color: var(--wtc-description-color, #666);' +
                '  margin: 0 0 24px 0;' +
                '}' +

                '.wtc-form {' +
                '  display: flex;' +
                '  flex-direction: column;' +
                '  gap: var(--wtc-field-gap, 20px);' +
                '}' +

                '.wtc-field {' +
                '  display: flex;' +
                '  flex-direction: column;' +
                '}' +

                '.wtc-field label {' +
                '  font-size: var(--wtc-label-font-size, 0.875rem);' +
                '  font-weight: var(--wtc-label-font-weight, 500);' +
                '  margin-bottom: 6px;' +
                '  color: var(--wtc-label-color, var(--wtc-text-color, #181818));' +
                '}' +

                '.wtc-required {' +
                '  color: var(--wtc-error-color, #c23934);' +
                '  margin-left: 2px;' +
                '}' +

                '.wtc-input {' +
                '  box-sizing: border-box;' +
                '  width: 100%;' +
                '  padding: var(--wtc-input-padding, 10px 12px);' +
                '  font-size: var(--wtc-input-font-size, 1rem);' +
                '  font-family: inherit;' +
                '  color: var(--wtc-text-color, #181818);' +
                '  background: var(--wtc-input-background, #ffffff);' +
                '  border: var(--wtc-input-border, 1px solid #c9c9c9);' +
                '  border-radius: var(--wtc-border-radius, 4px);' +
                '  transition: border-color 0.2s, box-shadow 0.2s;' +
                '}' +

                '.wtc-input:focus {' +
                '  outline: 2px solid var(--wtc-primary-color, #0176d3);' +
                '  outline-offset: -1px;' +
                '  border-color: var(--wtc-primary-color, #0176d3);' +
                '}' +

                '.wtc-input-error {' +
                '  border-color: var(--wtc-error-color, #c23934) !important;' +
                '  outline: 2px solid var(--wtc-error-color, #c23934) !important;' +
                '  outline-offset: -1px;' +
                '}' +

                '.wtc-textarea {' +
                '  resize: vertical;' +
                '  min-height: 100px;' +
                '}' +

                '.wtc-file-input {' +
                '  padding: 8px;' +
                '  background: #f9f9f9;' +
                '  border: var(--wtc-input-border, 1px solid #c9c9c9);' +
                '  border-radius: var(--wtc-border-radius, 4px);' +
                '  cursor: pointer;' +
                '}' +

                '.wtc-help {' +
                '  font-size: 0.75rem;' +
                '  color: #666;' +
                '  margin-top: 4px;' +
                '}' +

                '.wtc-submit {' +
                '  box-sizing: border-box;' +
                '  width: 100%;' +
                '  padding: var(--wtc-submit-padding, 12px 24px);' +
                '  font-size: var(--wtc-submit-font-size, 1rem);' +
                '  font-weight: 600;' +
                '  font-family: inherit;' +
                '  color: var(--wtc-submit-color, #fff);' +
                '  background: var(--wtc-submit-background, var(--wtc-primary-color, #0176d3));' +
                '  border: none;' +
                '  border-radius: var(--wtc-submit-border-radius, var(--wtc-border-radius, 4px));' +
                '  cursor: pointer;' +
                '  transition: background-color 0.2s, opacity 0.2s;' +
                '}' +

                '.wtc-submit:hover:not(:disabled) {' +
                '  opacity: 0.9;' +
                '}' +

                '.wtc-submit:disabled {' +
                '  opacity: 0.6;' +
                '  cursor: not-allowed;' +
                '}' +

                '.wtc-submit.wtc-loading {' +
                '  position: relative;' +
                '}' +

                '.wtc-error-message {' +
                '  padding: 12px 16px;' +
                '  font-size: 0.875rem;' +
                '  color: #721c24;' +
                '  background: var(--wtc-error-background, #f8d7da);' +
                '  border: var(--wtc-error-border, 1px solid #f5c6cb);' +
                '  border-radius: var(--wtc-border-radius, 4px);' +
                '}' +

                '.wtc-captcha-error {' +
                '  font-size: 0.75rem;' +
                '  color: var(--wtc-error-color, #c23934);' +
                '  margin-top: 8px;' +
                '}' +

                '.wtc-success {' +
                '  padding: 24px;' +
                '  text-align: center;' +
                '  color: var(--wtc-success-color, #2e844a);' +
                '  background: var(--wtc-success-background, #d4edda);' +
                '  border: var(--wtc-success-border, 1px solid #c3e6cb);' +
                '  border-radius: var(--wtc-border-radius, 4px);' +
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
                '  color: var(--wtc-success-color, #2e844a);' +
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
                '  border-top-color: var(--wtc-primary-color, #0176d3);' +
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
                '  color: var(--wtc-error-color, #c23934);' +
                '  background: #fef2f2;' +
                '  border: 1px solid #fecaca;' +
                '  border-radius: var(--wtc-border-radius, 4px);' +
                '}' +
            '</style>';
        }
    };

    /**
     * SubmissionMixin — shared methods used by both FormWidget and ConnectedForm.
     * These are non-DOM-touching pipeline methods that both classes need.
     */
    var SubmissionMixin = {
        fetchFormConfig:        FormWidget.prototype.fetchFormConfig,
        processSubmission:      FormWidget.prototype.processSubmission,
        submitForm:             FormWidget.prototype.submitForm,
        submitFormThenUploadChunks: FormWidget.prototype.submitFormThenUploadChunks,
        uploadFileInChunks:     FormWidget.prototype.uploadFileInChunks,
        uploadChunkSequentially: FormWidget.prototype.uploadChunkSequentially,
        pollUploadStatus:       FormWidget.prototype.pollUploadStatus,
        compressImageIfNeeded:  FormWidget.prototype.compressImageIfNeeded,
        readFileAsBase64:       FormWidget.prototype.readFileAsBase64,
        arrayBufferToBase64:    FormWidget.prototype.arrayBufferToBase64,
        generateUUID:           FormWidget.prototype.generateUUID,
        isValidEmail:           FormWidget.prototype.isValidEmail,
        isSupportedImage:       FormWidget.prototype.isSupportedImage,
        validateFile:           FormWidget.prototype.validateFile,
        escapeHtml:             FormWidget.prototype.escapeHtml,
        getCaptchaToken:        FormWidget.prototype.getCaptchaToken,
        resetCaptcha:           FormWidget.prototype.resetCaptcha,
        refreshNonce:           FormWidget.prototype.refreshNonce,
        loadImageCompression:   FormWidget.prototype.loadImageCompression,
        loadCaptcha:            FormWidget.prototype.loadCaptcha,
        renderCaptchaWidget:    FormWidget.prototype.renderCaptchaWidget
    };

    /**
     * ConnectedForm — binds submission logic to user's own HTML form.
     * No Shadow DOM, no rendered HTML. The user provides the form markup.
     *
     * @param {Object} options
     * @param {string} options.formName - Form name/identifier
     * @param {string} options.formSelector - CSS selector for the user's <form>
     * @param {string} options.apiBase - Base URL for REST API
     * @param {string} [options.fileInputSelector] - CSS selector for file <input>
     * @param {string} [options.captchaContainerId] - ID of element to render CAPTCHA into
     * @param {string} [options.errorContainerId] - ID of element for error messages
     * @param {string} [options.successContainerId] - ID of element for success state
     * @param {Function} [options.onSuccess] - Success callback (receives caseNumber)
     * @param {Function} [options.onError] - Error callback (receives error message)
     * @param {Function} [options.onLoad] - Called when form config is loaded
     */
    function ConnectedForm(options) {
        this.options = options;
        this.formConfig = null;
        this.formEl = null;
        this.fileInputEl = null;
        this.errorEl = null;
        this.successEl = null;
        this.captchaWidgetId = null;
        this.captchaResolve = null;
        this.captchaLightContainer = null;
        this.imageCompression = null;
        this._submitHandler = null;
        this._fieldListeners = [];
    }

    ConnectedForm.prototype = {
        /**
         * Initialize: resolve DOM, fetch config, attach listeners, load deps
         */
        init: function() {
            var self = this;

            // Resolve DOM elements
            this.formEl = document.querySelector(this.options.formSelector);
            if (!this.formEl) {
                console.error('WebToCaseForm.connect: Form not found:', this.options.formSelector);
                return;
            }

            if (this.options.fileInputSelector) {
                this.fileInputEl = document.querySelector(this.options.fileInputSelector);
            }
            if (this.options.errorContainerId) {
                this.errorEl = document.getElementById(this.options.errorContainerId);
            }
            if (this.options.successContainerId) {
                this.successEl = document.getElementById(this.options.successContainerId);
            }
            if (this.options.captchaContainerId) {
                this.captchaLightContainer = document.getElementById(this.options.captchaContainerId);
            }

            // Fetch form config
            this.fetchFormConfig()
                .then(function(config) {
                    self.formConfig = config;
                    self._warnMissingFields(config);
                    self._attachSubmitHandler();
                    self._attachFieldListeners();
                    self._loadDependencies();
                    if (self.options.onLoad) {
                        self.options.onLoad();
                    }
                })
                .catch(function(error) {
                    var msg = 'Failed to load form: ' + error;
                    console.error('WebToCaseForm.connect:', msg);
                    self.showFormError(msg);
                    if (self.options.onError) {
                        self.options.onError(msg);
                    }
                });
        },

        /**
         * Warn about missing fields in the user's HTML
         */
        _warnMissingFields: function(config) {
            if (!config.fields || !this.formEl) return;
            for (var i = 0; i < config.fields.length; i++) {
                var field = config.fields[i];
                var input = this.formEl.querySelector('[name="' + field.caseField + '"]');
                if (!input) {
                    console.warn(
                        'WebToCaseForm.connect: No input found for ' +
                        (field.required ? 'required ' : '') +
                        'field "' +
                        field.caseField + '" (label: "' + field.label + '"). ' +
                        'Add an input with name="' + field.caseField + '" to your form.'
                    );
                }
            }
        },

        /**
         * Attach submit handler to user's form
         */
        _attachSubmitHandler: function() {
            var self = this;
            this._submitHandler = function(e) {
                e.preventDefault();
                self.handleSubmit();
            };
            this.formEl.addEventListener('submit', this._submitHandler);
        },

        /**
         * Clear connect-mode errors/aria state while user edits fields
         */
        _attachFieldListeners: function() {
            var self = this;
            this._removeFieldListeners();

            var fields = this.formEl.querySelectorAll('input[name], textarea[name], select[name]');
            for (var i = 0; i < fields.length; i++) {
                var field = fields[i];
                var clearHandler = function() {
                    this.removeAttribute('aria-invalid');
                    self.hideError();
                };

                field.addEventListener('input', clearHandler);
                field.addEventListener('change', clearHandler);
                this._fieldListeners.push({
                    element: field,
                    handler: clearHandler
                });
            }
        },

        /**
         * Remove field listeners (used on destroy/re-init)
         */
        _removeFieldListeners: function() {
            for (var i = 0; i < this._fieldListeners.length; i++) {
                var listener = this._fieldListeners[i];
                listener.element.removeEventListener('input', listener.handler);
                listener.element.removeEventListener('change', listener.handler);
            }
            this._fieldListeners = [];
        },

        /**
         * Load dependencies (image compression, CAPTCHA)
         */
        _loadDependencies: function() {
            if (this.formConfig.enableFileUpload) {
                this.loadImageCompression();
            }
            if (this.formConfig.enableCaptcha && this.formConfig.captchaSiteKey) {
                this.loadCaptcha();
            }
        },

        /**
         * Handle form submission
         */
        handleSubmit: function() {
            var self = this;
            var config = this.formConfig;
            this.hideError();

            // Validate form
            var errors = this.validateForm();
            if (errors.length > 0) {
                this.showFormError(errors.join('<br>'));
                return;
            }

            // Validate CAPTCHA (v2 checkbox)
            var captchaType = config.captchaType || 'V2_Checkbox';
            if (config.enableCaptcha && captchaType === 'V2_Checkbox') {
                if (typeof grecaptcha === 'undefined' || this.captchaWidgetId === null) {
                    this.showFormError('Verification is still loading. Please try again.');
                    return;
                }

                var token = grecaptcha.getResponse(this.captchaWidgetId);
                if (!token) {
                    this.showFormError('Please complete the verification.');
                    return;
                }
            }

            // Collect field values
            var fieldValues = this.collectFieldValues();

            // Get file
            var file = null;
            if (this.fileInputEl && this.fileInputEl.files && this.fileInputEl.files.length > 0) {
                file = this.fileInputEl.files[0];
            }

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
         * Validate form fields using form config + user's DOM
         */
        validateForm: function() {
            var errors = [];
            var config = this.formConfig;
            if (!config.fields) return errors;

            for (var i = 0; i < config.fields.length; i++) {
                var field = config.fields[i];
                if (!field.required) continue;

                var input = this.formEl.querySelector('[name="' + field.caseField + '"]');
                if (!input) continue;

                var value = input.value.trim();

                if (!value) {
                    errors.push(field.label + ' is required.');
                    input.setAttribute('aria-invalid', 'true');
                } else if (field.type === 'Email' && !this.isValidEmail(value)) {
                    errors.push('Please enter a valid email address.');
                    input.setAttribute('aria-invalid', 'true');
                } else {
                    input.removeAttribute('aria-invalid');
                }
            }

            return errors;
        },

        /**
         * Collect field values from user's form (only fields defined in config)
         */
        collectFieldValues: function() {
            var values = {};
            var config = this.formConfig;
            if (!config.fields) return values;

            for (var i = 0; i < config.fields.length; i++) {
                var field = config.fields[i];
                var input = this.formEl.querySelector('[name="' + field.caseField + '"]');
                if (input) {
                    values[field.caseField] = input.value.trim();
                }
            }

            return values;
        },

        /**
         * Set loading state on submit button
         */
        setLoading: function(loading) {
            var button = this.formEl.querySelector('[type="submit"]');
            if (button) {
                button.disabled = loading;
                if (loading) {
                    button.setAttribute('data-original-text', button.textContent);
                    button.textContent = 'Submitting...';
                } else {
                    var originalText = button.getAttribute('data-original-text');
                    if (originalText) {
                        button.textContent = originalText;
                    }
                }
            }
        },

        /**
         * Update button text (for progress updates)
         */
        updateButtonText: function(text) {
            var button = this.formEl.querySelector('[type="submit"]');
            if (button) {
                button.textContent = text;
            }
        },

        /**
         * Show error message (DOM only — mixin code calls onError separately)
         */
        showFormError: function(message) {
            if (this.errorEl) {
                this.errorEl.innerHTML = message;
                this.errorEl.hidden = false;
            }
        },

        /**
         * Hide error message
         */
        hideError: function() {
            if (this.errorEl) {
                this.errorEl.hidden = true;
                this.errorEl.innerHTML = '';
            }
        },

        /**
         * Show success state — hide form, show success container, fill case number
         */
        showSuccess: function(caseNumber) {
            if (this.formEl) {
                this.formEl.hidden = true;
            }
            if (this.successEl) {
                this.successEl.hidden = false;
                var caseSpan = this.successEl.querySelector('[data-wtc-case-number]');
                if (caseSpan) {
                    caseSpan.textContent = caseNumber;
                }
            }
            if (this.captchaLightContainer) {
                this.captchaLightContainer.style.display = 'none';
            }
            this.hideError();
        },

        /**
         * No-op stubs for methods called by mixin that are Shadow-DOM-specific
         */
        showCaptchaError: function() {},
        hideCaptchaError: function() {},

        /**
         * Clean up — remove listener, CAPTCHA script
         */
        destroy: function() {
            if (this.formEl && this._submitHandler) {
                this.formEl.removeEventListener('submit', this._submitHandler);
                this._submitHandler = null;
            }
            this._removeFieldListeners();
            // Clean up CAPTCHA globals
            if (window.wtcCaptchaOnload) {
                delete window.wtcCaptchaOnload;
            }
            if (window.wtcCaptchaSuccess) {
                delete window.wtcCaptchaSuccess;
            }
        }
    };

    // Copy mixin methods onto ConnectedForm prototype (skip already-defined)
    for (var key in SubmissionMixin) {
        if (SubmissionMixin.hasOwnProperty(key) && !ConnectedForm.prototype.hasOwnProperty(key)) {
            ConnectedForm.prototype[key] = SubmissionMixin[key];
        }
    }

    /**
     * Connect mode — bind submission logic to user's own HTML form
     */
    WebToCaseForm.connect = function(options) {
        if (!options || !options.formName || !options.formSelector || !options.apiBase) {
            console.error('WebToCaseForm.connect: Missing required options (formName, formSelector, apiBase)');
            return null;
        }
        var instance = new ConnectedForm(options);
        instance.init();
        return instance;
    };

    // Export to global scope
    global.WebToCaseForm = WebToCaseForm;

})(typeof window !== 'undefined' ? window : this);
