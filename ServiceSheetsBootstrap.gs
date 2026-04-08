/**
 * ServiceSheetsBootstrap.gs — explicit bootstrap helpers for service journal sheets.
 */

function bootstrapWasbRuntimeAndAlertsSheets() {
  const basicSheets = (typeof stage7EnsureBasicRequiredSheets_ === 'function')
    ? stage7EnsureBasicRequiredSheets_()
    : [];

  let access = { success: false, sheet: appGetCore('ACCESS_SHEET', 'ACCESS') };
  try {
    if (typeof _getSheet_ === 'function') {
      const sh = _getSheet_(true);
      access = { success: !!sh, sheet: sh ? sh.getName() : appGetCore('ACCESS_SHEET', 'ACCESS') };
    }
  } catch (_) {}

  const runtime = (typeof JobRuntimeRepository_ === 'object' && JobRuntimeRepository_.ensureSheet)
    ? JobRuntimeRepository_.ensureSheet()
    : { success: false, sheet: (typeof STAGE7_CONFIG !== 'undefined' ? STAGE7_CONFIG.JOB_RUNTIME_SHEET : 'JOB_RUNTIME_LOG') };

  const alerts = (typeof AlertsRepository_ === 'object' && AlertsRepository_.ensureSheet)
    ? AlertsRepository_.ensureSheet()
    : { success: false, sheet: (typeof appGetCore === 'function' ? appGetCore('ALERTS_SHEET', 'ALERTS_LOG') : 'ALERTS_LOG') };

  const audit = (typeof Stage7AuditTrail_ === 'object' && Stage7AuditTrail_.ensureSheet)
    ? { success: true, sheet: Stage7AuditTrail_.ensureSheet().getName() }
    : { success: false, sheet: (typeof STAGE7_CONFIG !== 'undefined' ? STAGE7_CONFIG.AUDIT_SHEET : 'AUDIT_LOG') };

  const operations = (typeof OperationRepository_ === 'object' && OperationRepository_.ensureServiceSheets)
    ? OperationRepository_.ensureServiceSheets()
    : {};

  const templates = (typeof ensureTemplatesSheet_ === 'function')
    ? ensureTemplatesSheet_()
    : null;

  const logSheet = (typeof _ensureLogSheet_ === 'function')
    ? _ensureLogSheet_()
    : null;

  const ensuredSheets = []
    .concat(basicSheets || [])
    .concat([runtime.sheet, alerts.sheet, audit.sheet])
    .concat(Object.keys(operations || {}).map(function(key) { return operations[key]; }))
    .concat([access.sheet, templates ? templates.getName() : null, logSheet ? logSheet.getName() : null])
    .filter(Boolean);

  return {
    success: runtime.success !== false && alerts.success !== false && audit.success !== false,
    message: 'Обов’язкові та службові листи підготовлено',
    sheets: Array.from(new Set(ensuredSheets)),
    basicSheets: basicSheets,
    access: access,
    runtime: runtime,
    alerts: alerts,
    audit: audit,
    operations: operations
  };
}