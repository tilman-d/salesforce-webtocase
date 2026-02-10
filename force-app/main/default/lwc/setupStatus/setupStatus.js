import { LightningElement, track } from 'lwc';
import getFullStatus from '@salesforce/apex/SetupWizardController.getFullStatus';

const CAPTCHA_TYPE_LABELS = {
    V2_Checkbox: 'v2 Checkbox',
    V2_Invisible: 'v2 Invisible',
    V3_Score: 'v3 Score-based'
};

export default class SetupStatus extends LightningElement {
    @track status;
    isLoading = true;
    showPermissionDetails = false;
    error;
    _copyLabel;

    connectedCallback() {
        this.loadStatus();
    }

    loadStatus() {
        this.isLoading = true;
        this.error = undefined;
        getFullStatus()
            .then(result => {
                this.status = result;
            })
            .catch(error => {
                this.error = error?.body?.message || error?.message || 'Unknown error';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRefresh() {
        this.loadStatus();
    }

    togglePermissionDetails() {
        this.showPermissionDetails = !this.showPermissionDetails;
    }

    handleCopyUrl() {
        const url = this.status?.publicFormUrl;
        if (!url) return;

        const el = document.createElement('textarea');
        el.value = url;
        el.setAttribute('readonly', '');
        el.style.position = 'absolute';
        el.style.left = '-9999px';
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);

        // Brief visual feedback via button label change
        this._copyLabel = 'Copied!';
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._copyLabel = undefined; }, 1500);
    }

    handleOpenUrl() {
        const url = this.status?.publicFormUrl;
        if (url) {
            window.open(url, '_blank', 'noopener,noreferrer');
        }
    }

    // --- Computed getters ---

    get isConfigured() {
        return this.status?.isConfigured === true;
    }

    get hasError() {
        return !!this.error || !!this.status?.errorMessage;
    }

    get displayError() {
        return this.error || this.status?.errorMessage;
    }

    get siteStatusVariant() {
        return this.status?.siteStatus === 'Active' ? 'success' : 'warning';
    }

    get siteStatusLabel() {
        return this.status?.siteStatus || 'Unknown';
    }

    get permissionsSummary() {
        if (this.status?.permissionsError) {
            return 'Unable to check';
        }
        return (this.status?.permissionsPassing ?? 0) + ' / ' + (this.status?.permissionsTotal ?? 0) + ' passing';
    }

    get permissionsIconName() {
        if (this.status?.allPermissionsPassed) return 'utility:success';
        if (this.status?.permissionsPassing > 0) return 'utility:warning';
        return 'utility:error';
    }

    get permissionsIconVariant() {
        if (this.status?.allPermissionsPassed) return 'success';
        if (this.status?.permissionsPassing > 0) return 'warning';
        return 'error';
    }

    get hasPermissions() {
        return this.status?.permissions?.length > 0;
    }

    get permissionRows() {
        if (!this.status?.permissions) return [];
        return this.status.permissions.map((p, idx) => ({
            key: idx,
            name: p.name,
            permissionType: p.permissionType,
            configured: p.configured,
            statusLabel: p.configured ? 'Passing' : 'Missing',
            statusClass: p.configured ? 'slds-text-color_success' : 'slds-text-color_error',
            iconName: p.configured ? 'utility:success' : 'utility:close',
            iconVariant: p.configured ? 'success' : 'error'
        }));
    }

    get toggleDetailsLabel() {
        return this.showPermissionDetails ? 'Hide Details' : 'Show Details';
    }

    get recaptchaStatusLabel() {
        return this.status?.recaptchaConfigured ? 'Configured' : 'Not Configured';
    }

    get recaptchaTypeLabel() {
        return CAPTCHA_TYPE_LABELS[this.status?.recaptchaType] || this.status?.recaptchaType || '';
    }

    get copyButtonLabel() {
        return this._copyLabel || 'Copy URL';
    }

    get hasPublicFormUrl() {
        return !!this.status?.publicFormUrl;
    }

    get hasSiteBaseUrl() {
        return !!this.status?.siteBaseUrl;
    }
}
