/**
 * Stage7LegacyApiWrappers.gs — self-contained compatibility shims for removed legacy APIs.
 *
 * Goal: keep diagnostics, old menu actions, historical entrypoints and thin external callers
 * working against the canonical Stage 7.1.2 final-clean APIs.
 */

function apiGetMonthsList() {
  return apiStage4GetMonthsList();
}

function apiGetSidebarData(dateStr) {
  return apiStage4GetSidebarData(dateStr || '');
}

function apiGenerateSendPanel(options) {
  return apiGenerateSendPanelForDate(options || {});
}

function apiGetSendPanelData() {
  return apiStage4GetSendPanelData();
}

function apiMarkSendPanelRowsAsSent(rowNumbers, options) {
  return apiMarkPanelRowsAsSent(rowNumbers || [], options || {});
}

function apiGetDaySummary(dateStr) {
  return apiBuildDaySummary(dateStr || '');
}

function apiGetDetailedDaySummary(dateStr) {
  return apiBuildDetailedSummary(dateStr || '');
}

function apiCheckVacations(dateStr) {
  return apiCheckVacationsAndBirthdays(dateStr || '');
}

function apiGetBirthdays(dateStr) {
  return apiCheckVacationsAndBirthdays(dateStr || '');
}

function apiBuildBirthdayLink(phone, name) {
  return apiStage4BuildBirthdayLink(phone || '', name || '');
}

function apiGetPersonCardData(callsign, dateStr) {
  return apiOpenPersonCard(callsign || '', dateStr || '');
}

function apiSwitchBotToMonth(monthSheetName) {
  return apiStage4SwitchBotToMonth(monthSheetName || '');
}

function apiCreateNextMonth(options) {
  return apiCreateNextMonthStage4(options || {});
}

function apiSetupVacationTriggers() {
  return apiStage4SetupVacationTriggers();
}

function apiCleanupDuplicateTriggers(functionName) {
  return apiStage4CleanupDuplicateTriggers(functionName || '');
}

function apiDebugPhones() {
  return apiStage4DebugPhones();
}

function apiClearCache() {
  return apiStage4ClearCache();
}

function apiClearPhoneCache() {
  return apiStage4ClearPhoneCache();
}

function apiClearLog() {
  return apiStage4ClearLog();
}

function apiHealthCheck(options) {
  return apiStage4HealthCheck(options || {});
}

function apiRunRegressionTests(options) {
  return apiRunStage4RegressionTests(options || {});
}

function _pickTestCallsign() {
  return _pickTestCallsign_();
}
