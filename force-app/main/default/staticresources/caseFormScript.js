/**
 * Web-to-Case Form Script
 * Handles form validation, file upload, reCAPTCHA, and submission via Visualforce Remoting
 */
(function() {
    'use strict';

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
            console.log('CaseForm: reCAPTCHA is enabled');
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
     * Handle form submission
     */
    function handleSubmit(e) {
        e.preventDefault();

        var form = e.target;
        var submitButton = document.getElementById('submitButton');

        // Validate form
        var validationErrors = validateForm(form);
        if (validationErrors.length > 0) {
            showError(validationErrors.join('<br>'));
            return;
        }

        // Validate reCAPTCHA if enabled
        var captchaToken = '';
        if (formConfig.enableCaptcha) {
            captchaToken = getCaptchaToken();
            if (!captchaToken) {
                showCaptchaError();
                showError('Please complete the CAPTCHA verification.');
                return;
            }
            hideCaptchaError();
        }

        // Collect field values
        var fieldValues = collectFieldValues(form);

        // Check for file
        var fileInput = document.getElementById('fileInput');
        var hasFile = fileInput && fileInput.files && fileInput.files.length > 0;

        if (hasFile) {
            var file = fileInput.files[0];

            // Validate file size
            if (file.size > formConfig.maxFileSize) {
                var maxMB = Math.round(formConfig.maxFileSize / 1024 / 1024);
                showError('File size exceeds the maximum allowed (' + maxMB + ' MB).');
                return;
            }

            // Read file and submit
            setLoading(true);
            readFileAsBase64(file, function(base64Content) {
                submitToSalesforce(fieldValues, file.name, base64Content, captchaToken);
            }, function(error) {
                setLoading(false);
                showError('Error reading file: ' + error);
            });
        } else {
            // Submit without file
            setLoading(true);
            submitToSalesforce(fieldValues, '', '', captchaToken);
        }
    }

    /**
     * Get reCAPTCHA token if available
     */
    function getCaptchaToken() {
        if (typeof grecaptcha !== 'undefined') {
            try {
                return grecaptcha.getResponse();
            } catch (e) {
                console.error('CaseForm: Error getting reCAPTCHA response:', e);
                return '';
            }
        }
        return '';
    }

    /**
     * Reset reCAPTCHA widget
     */
    function resetCaptcha() {
        if (typeof grecaptcha !== 'undefined') {
            try {
                grecaptcha.reset();
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
