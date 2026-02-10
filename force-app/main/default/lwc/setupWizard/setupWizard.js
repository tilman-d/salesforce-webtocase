import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import SETUP_STATUS_REFRESH from '@salesforce/messageChannel/SetupStatusRefresh__c';
import checkPreconditions from '@salesforce/apex/SetupWizardController.checkPreconditions';
import getActiveSites from '@salesforce/apex/SetupWizardController.getActiveSites';
import getSetupStatus from '@salesforce/apex/SetupWizardController.getSetupStatus';
import configurePermissions from '@salesforce/apex/SetupWizardController.configurePermissions';
import validateConfiguration from '@salesforce/apex/SetupWizardController.validateConfiguration';
import createSampleForm from '@salesforce/apex/SetupWizardController.createSampleForm';
import getPublicUrl from '@salesforce/apex/SetupWizardController.getPublicUrl';
import getReCaptchaSettings from '@salesforce/apex/SetupWizardController.getReCaptchaSettings';
import saveReCaptchaSettings from '@salesforce/apex/SetupWizardController.saveReCaptchaSettings';
import saveDefaultSite from '@salesforce/apex/SetupWizardController.saveDefaultSite';

const STEPS = [
    { label: 'Welcome', value: '1' },
    { label: 'Select Site', value: '2' },
    { label: 'Configure', value: '3' },
    { label: 'Verify', value: '4' },
    // v1 MVP: reCAPTCHA step hidden — uncomment for v2
    // { label: 'reCAPTCHA', value: '5' },
    { label: 'Complete', value: '5' }
];

export default class SetupWizard extends LightningElement {
    @wire(MessageContext) messageContext;

    @track currentStep = '1';
    @track isLoading = true;

    // Step 1 - Preconditions
    @track preconditions = null;
    @track preconditionsChecked = false;

    // Step 2 - Site Selection
    @track sites = [];
    @track selectedSiteId = '';
    @track selectedSite = null;

    // Step 3 - Auto Configuration
    @track securityAcknowledged = false;
    @track configResults = [];
    @track autoConfigComplete = false;
    @track autoConfigSuccess = false;

    // Step 4 - Manual Steps
    @track validationResults = [];
    @track validationPassed = false;

    // Step 5 - reCAPTCHA Configuration
    @track recaptchaSiteKey = '';
    @track recaptchaSecretKey = '';
    @track recaptchaType = 'V2_Checkbox';
    @track recaptchaConfigured = false;
    @track recaptchaSkipped = false;

    // Step 6 - Complete
    @track publicUrl = '';
    @track sampleFormCreated = false;
    @track sampleFormId = '';

    steps = STEPS;

    connectedCallback() {
        this.loadPreconditions();
    }

    get currentStepNumber() {
        return parseInt(this.currentStep, 10);
    }

    // Check if a specific step's requirements are met
    isStepComplete(stepNum) {
        switch (stepNum) {
            case 1:
                return this.preconditions?.allPassed === true;
            case 2:
                return !!this.selectedSiteId;
            case 3:
                return this.autoConfigComplete === true;
            case 4:
                return this.validationPassed === true;
            // v1 MVP: case 5 was reCAPTCHA (optional) — renumbered for v2
            case 5:
                return true; // Final step
            default:
                return false;
        }
    }

    // Check if navigation to a target step is allowed
    canNavigateToStep(targetStep) {
        // Can always go back to previous steps
        if (targetStep <= this.currentStepNumber) {
            return true;
        }
        // For forward navigation, check all intermediate steps are complete
        for (let i = this.currentStepNumber; i < targetStep; i++) {
            if (!this.isStepComplete(i)) {
                return false;
            }
        }
        return true;
    }

    get isStep1() {
        return this.currentStep === '1';
    }

    get isStep2() {
        return this.currentStep === '2';
    }

    get isStep3() {
        return this.currentStep === '3';
    }

    get isStep4() {
        return this.currentStep === '4';
    }

    get isStep5() {
        return this.currentStep === '5'; // v1 MVP: now maps to Complete step
    }

    get isStep6() {
        return false; // v1 MVP: always false — kept for v2 re-enablement
    }

    get canGoBack() {
        return this.currentStepNumber > 1;
    }

    get canGoNext() {
        switch (this.currentStep) {
            case '1':
                return this.preconditions?.allPassed;
            case '2':
                return !!this.selectedSiteId;
            case '3':
                return this.autoConfigComplete;
            case '4':
                return this.validationPassed;
            // v1 MVP: case '5' was reCAPTCHA — removed for v2
            default:
                return false;
        }
    }

    get nextButtonLabel() {
        if (this.currentStep === '4') { // v1 MVP: was '5' — update for v2
            return 'Finish';
        }
        return 'Next';
    }

    get showBackButton() {
        return this.currentStepNumber > 1 && this.currentStepNumber < 5; // v1 MVP: was < 6
    }

    get showNextButton() {
        return this.currentStepNumber < 5; // v1 MVP: was < 6
    }

    get hasSites() {
        return this.sites && this.sites.length > 0;
    }

    get displayUrl() {
        if (this.sampleFormCreated && this.publicUrl) {
            return this.publicUrl + '?form=contact-support';
        }
        return this.publicUrl;
    }

    get recaptchaTypeOptions() {
        return [
            { label: 'v2 Checkbox ("I\'m not a robot") (Recommended)', value: 'V2_Checkbox' },
            { label: 'v2 Invisible', value: 'V2_Invisible' },
            { label: 'v3 Score-based', value: 'V3_Score' }
        ];
    }

    get isV3Score() {
        return this.recaptchaType === 'V3_Score';
    }

    get siteOptions() {
        return this.sites.map(site => ({
            label: `${site.masterLabel} (${site.status})`,
            value: site.id
        }));
    }

    get automatablePermissions() {
        return this.configResults.filter(p => p.canAutomate);
    }

    get manualPermissions() {
        return this.validationResults.filter(p => !p.canAutomate);
    }

    get hasFailedAutomatable() {
        return this.configResults.some(p => p.canAutomate && !p.configured);
    }

    get hasConfiguredPermissions() {
        return this.configResults.some(p => p.configured);
    }

    get isConfigureDisabled() {
        return !this.securityAcknowledged;
    }

    get isNextDisabled() {
        return !this.canGoNext;
    }

    // Step 1: Load preconditions
    async loadPreconditions() {
        this.isLoading = true;
        try {
            this.preconditions = await checkPreconditions();
            this.preconditionsChecked = true;
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Step 2: Load sites
    async loadSites() {
        this.isLoading = true;
        try {
            this.sites = await getActiveSites();
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSiteSelection(event) {
        this.selectedSiteId = event.detail.value;
        this.selectedSite = this.sites.find(s => s.id === this.selectedSiteId);
    }

    handleRefreshSites() {
        this.loadSites();
    }

    handleOpenSitesSetup() {
        window.open('/lightning/setup/Sites/home', '_blank');
    }

    // Step 3: Security acknowledgment
    handleSecurityAcknowledge(event) {
        this.securityAcknowledged = event.target.checked;
    }

    async handleAutoConfig() {
        if (!this.securityAcknowledged) {
            this.showToast('Warning', 'Please acknowledge the security warning before proceeding.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const result = await configurePermissions({ siteId: this.selectedSiteId });
            this.configResults = result.results;
            this.autoConfigComplete = true;
            this.autoConfigSuccess = result.success;

            if (result.success) {
                this.showToast('Success', 'Permissions configured successfully!', 'success');
            } else {
                this.showToast('Partial Success', 'Some permissions could not be configured. See details below.', 'warning');
            }
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRetryConfig() {
        this.autoConfigComplete = false;
        this.configResults = [];
        await this.handleAutoConfig();
    }

    // Step 4: Validation
    async loadValidation() {
        this.isLoading = true;
        try {
            const result = await validateConfiguration({ siteId: this.selectedSiteId });
            this.validationResults = result.permissions;
            this.validationPassed = result.allPassed;
            this.publicUrl = result.publicUrl;

            if (this.validationPassed) {
                this.showToast('Success', 'All configurations validated successfully!', 'success');
            }
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleValidate() {
        this.loadValidation();
    }

    // Step 5: reCAPTCHA Configuration
    async loadRecaptchaSettings() {
        this.isLoading = true;
        try {
            const result = await getReCaptchaSettings();
            if (result.errorMessage) {
                this.showToast('Warning', result.errorMessage, 'warning');
            } else {
                if (result.siteKey) {
                    this.recaptchaSiteKey = result.siteKey;
                }
                if (result.captchaType) {
                    this.recaptchaType = result.captchaType;
                }
                this.recaptchaConfigured = result.isConfigured;
            }
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRecaptchaSiteKeyChange(event) {
        this.recaptchaSiteKey = event.target.value;
    }

    handleRecaptchaSecretKeyChange(event) {
        this.recaptchaSecretKey = event.target.value;
    }

    handleRecaptchaTypeChange(event) {
        this.recaptchaType = event.detail.value;
    }

    async handleSaveRecaptcha() {
        // For initial setup, require both keys
        // For updates when already configured, keys are optional (backend preserves existing)
        if (!this.recaptchaConfigured) {
            if (!this.recaptchaSiteKey || !this.recaptchaSecretKey) {
                this.showToast('Warning', 'Please enter both Site Key and Secret Key.', 'warning');
                return;
            }
        }

        this.isLoading = true;
        try {
            const result = await saveReCaptchaSettings({
                siteKey: this.recaptchaSiteKey || null,      // Pass null if empty (backend preserves existing)
                secretKey: this.recaptchaSecretKey || null,  // Pass null if empty (backend preserves existing)
                captchaType: this.recaptchaType,
                scoreThreshold: null  // Uses default (0.3) from Custom Metadata field
            });

            if (result.errorMessage) {
                this.showToast('Error', result.errorMessage, 'error');
            } else {
                this.recaptchaConfigured = result.isConfigured;
                this.recaptchaType = result.captchaType || 'V2_Checkbox';
                // Clear the secret key input after successful save (defense-in-depth)
                this.recaptchaSecretKey = '';
                this.showToast('Success', 'reCAPTCHA settings saved successfully!', 'success');
            }
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSkipRecaptcha() {
        this.recaptchaSkipped = true;
        // Clear any entered values
        this.recaptchaSiteKey = '';
        this.recaptchaSecretKey = '';
        // Proceed to next step
        this.handleNext();
    }

    handleOpenRecaptchaAdmin() {
        window.open('https://www.google.com/recaptcha/admin', '_blank');
    }

    handleGoBackToRecaptcha() {
        this.currentStep = '5';
    }

    // Step 6: Complete
    async loadPublicUrl() {
        try {
            this.publicUrl = await getPublicUrl({ siteId: this.selectedSiteId, formName: null });
        } catch (error) {
            console.error('Error getting public URL:', error);
        }
    }

    handleCopyUrl() {
        const urlToCopy = this.displayUrl;
        if (urlToCopy) {
            navigator.clipboard.writeText(urlToCopy).then(() => {
                this.showToast('Copied', 'URL copied to clipboard', 'success');
            }).catch(() => {
                this.showToast('Error', 'Could not copy URL', 'error');
            });
        }
    }

    handleTestForm() {
        if (this.publicUrl) {
            // Use sample form if created, otherwise open base URL
            let url = this.publicUrl;
            if (this.sampleFormCreated) {
                url += '?form=contact-support';
            }
            window.open(url, '_blank');
        }
    }

    async handleCreateSampleForm() {
        this.isLoading = true;
        try {
            this.sampleFormId = await createSampleForm();
            this.sampleFormCreated = true;
            this.showToast('Success', 'Sample form created successfully!', 'success');
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleViewSampleForm() {
        if (this.publicUrl && this.sampleFormCreated) {
            const url = this.publicUrl + '?form=contact-support';
            window.open(url, '_blank');
        }
    }

    handleGoToFormManager() {
        // Navigate to Form Manager tab
        window.location.href = '/lightning/n/Form_Manager';
    }

    // Navigation
    handleBack() {
        const step = this.currentStepNumber;
        if (step > 1) {
            this.currentStep = String(step - 1);
        }
    }

    // Handle clicking on a step in the progress path
    async handleStepClick(event) {
        // Get step value from the target element's dataset
        const stepValue = event.target.dataset.step || event.currentTarget.dataset.step;
        if (!stepValue) {
            return;
        }

        const targetStep = parseInt(stepValue, 10);
        const currentStepNum = this.currentStepNumber;

        // No action if clicking current step
        if (targetStep === currentStepNum) {
            return;
        }

        // Check if navigation is allowed
        if (!this.canNavigateToStep(targetStep)) {
            this.showToast('Warning', 'Please complete the current step first.', 'warning');
            return;
        }

        // Navigate to the target step
        this.currentStep = stepValue;

        // Load step-specific data as needed
        if (targetStep === 2 && this.sites.length === 0) {
            await this.loadSites();
        } else if (targetStep === 4) {
            await this.loadValidation();
        // v1 MVP: targetStep === 5 was loadRecaptchaSettings — removed for v2
        } else if (targetStep === 5) {
            await this.loadPublicUrl();
        }
    }

    async handleNext() {
        const step = this.currentStepNumber;

        if (step === 1) {
            // Moving from Welcome to Select Site
            this.currentStep = '2';
            await this.loadSites();
        } else if (step === 2) {
            // Moving from Select Site to Configure
            // Save the selected Site as the default before proceeding
            try {
                await saveDefaultSite({ siteId: this.selectedSiteId });
            } catch (error) {
                this.showToast('Error', this.getErrorMessage(error), 'error');
                return;
            }
            this.currentStep = '3';
            this.autoConfigComplete = false;
            this.configResults = [];
            this.securityAcknowledged = false;
        } else if (step === 3) {
            // Moving from Configure to Verify
            this.currentStep = '4';
            await this.loadValidation();
        } else if (step === 4) {
            // v1 MVP: skip reCAPTCHA, go directly to Complete
            this.currentStep = '5';
            await this.loadPublicUrl();
            publish(this.messageContext, SETUP_STATUS_REFRESH, {});
            // v1 MVP: old step === 5 (reCAPTCHA → Complete) removed — restore for v2
        }
    }

    // Utilities
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'An unexpected error occurred';
    }
}
