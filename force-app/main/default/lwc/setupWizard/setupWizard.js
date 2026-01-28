import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkPreconditions from '@salesforce/apex/SetupWizardController.checkPreconditions';
import getActiveSites from '@salesforce/apex/SetupWizardController.getActiveSites';
import getSetupStatus from '@salesforce/apex/SetupWizardController.getSetupStatus';
import configurePermissions from '@salesforce/apex/SetupWizardController.configurePermissions';
import validateConfiguration from '@salesforce/apex/SetupWizardController.validateConfiguration';
import createSampleForm from '@salesforce/apex/SetupWizardController.createSampleForm';
import getPublicUrl from '@salesforce/apex/SetupWizardController.getPublicUrl';

const STEPS = [
    { label: 'Welcome', value: '1' },
    { label: 'Select Site', value: '2' },
    { label: 'Configure', value: '3' },
    { label: 'Verify', value: '4' },
    { label: 'Complete', value: '5' }
];

export default class SetupWizard extends LightningElement {
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

    // Step 5 - Complete
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
        return this.currentStep === '5';
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
            default:
                return false;
        }
    }

    get nextButtonLabel() {
        if (this.currentStep === '4') {
            return 'Finish';
        }
        return 'Next';
    }

    get showBackButton() {
        return this.currentStepNumber > 1 && this.currentStepNumber < 5;
    }

    get showNextButton() {
        return this.currentStepNumber < 5;
    }

    get hasSites() {
        return this.sites && this.sites.length > 0;
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

    // Step 5: Complete
    async loadPublicUrl() {
        try {
            this.publicUrl = await getPublicUrl({ siteId: this.selectedSiteId, formName: null });
        } catch (error) {
            console.error('Error getting public URL:', error);
        }
    }

    handleCopyUrl() {
        if (this.publicUrl) {
            navigator.clipboard.writeText(this.publicUrl).then(() => {
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

    async handleNext() {
        const step = this.currentStepNumber;

        if (step === 1) {
            // Moving from Welcome to Select Site
            this.currentStep = '2';
            await this.loadSites();
        } else if (step === 2) {
            // Moving from Select Site to Configure
            this.currentStep = '3';
            this.autoConfigComplete = false;
            this.configResults = [];
            this.securityAcknowledged = false;
        } else if (step === 3) {
            // Moving from Configure to Verify
            this.currentStep = '4';
            await this.loadValidation();
        } else if (step === 4) {
            // Moving from Verify to Complete
            this.currentStep = '5';
            await this.loadPublicUrl();
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
