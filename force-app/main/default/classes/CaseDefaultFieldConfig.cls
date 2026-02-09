/**
 * Single source of truth for the allowlist of Case fields that can be set
 * via Default Case Values on Form__c. Used by both FormAdminController
 * (config-time validation) and CaseFormController (submission-time application).
 */
public class CaseDefaultFieldConfig {
    public static final Set<String> ALLOWED_FIELDS = new Set<String>{
        'Priority', 'Status', 'Origin', 'Type', 'Reason'
    };
}
