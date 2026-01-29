/**
 * Web-to-Case Form Script
 * Handles form validation, file upload, reCAPTCHA (v2 Checkbox, v2 Invisible, v3 Score), and submission via Visualforce Remoting
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

        // Validate file size if file present
        if (file && file.size > formConfig.maxFileSize) {
            var maxMB = Math.round(formConfig.maxFileSize / 1024 / 1024);
            showError('File size exceeds the maximum allowed (' + maxMB + ' MB).');
            return;
        }

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
            readFileAsBase64(file, function(base64Content) {
                submitToSalesforce(fieldValues, file.name, base64Content, captchaToken);
            }, function(error) {
                setLoading(false);
                showError('Error reading file: ' + error);
            });
        } else {
            submitToSalesforce(fieldValues, '', '', captchaToken);
        }
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
            errorDiv.innerHTML = message;
            errorDiv.style.display = 'block';
            // Scroll to error
            errorDiv.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
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
