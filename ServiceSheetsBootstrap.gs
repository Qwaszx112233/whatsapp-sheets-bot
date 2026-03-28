/**
 * ServiceSheetsBootstrap.gs — explicit bootstrap helpers for service journal sheets.
 */

function bootstrapWapbRuntimeAndAlertsSheets() {
  const runtime = (typeof JobRuntimeRepository_ === 'object' && JobRuntimeRepository_.ensureSheet)
    ? JobRuntimeRepository_.ensureSheet()
    : { success: false, sheet: (typeof STAGE5_CONFIG !== 'undefined' ? STAGE5_CONFIG.JOB_RUNTIME_SHEET : 'JOB_RUNTIME_LOG') };
  const alerts = (typeof AlertsRepository_ === 'object' && AlertsRepository_.ensureSheet)
    ? AlertsRepository_.ensureSheet()
    : { success: false, sheet: (typeof appGetCore === 'function' ? appGetCore('ALERTS_SHEET', 'ALERTS_LOG') : 'ALERTS_LOG') };

  return {
    success: runtime.success !== false && alerts.success !== false,
    message: 'Службові листи журналів підготовлено',
    sheets: [runtime.sheet, alerts.sheet].filter(Boolean),
    runtime: runtime,
    alerts: alerts
  };
}

function apiStage5BootstrapRuntimeAndAlertsSheets() {
  const result = bootstrapWapbRuntimeAndAlertsSheets();
  return _stage5BuildMaintenanceResponse_(
    result.success !== false,
    result.message || 'Службові листи журналів підготовлено',
    result,
    'stage5BootstrapRuntimeAndAlertsSheets',
    result.success === false ? ['Не вдалося підготувати службові листи журналів'] : [],
    { affectedSheets: result.sheets || [] }
  );
}
