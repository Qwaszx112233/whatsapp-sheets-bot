/**
 * Stage7ServerApi.gs — canonical Stage 7 application API.
 *
 * Hot-path read routes are intentionally short here.
 * Heavy orchestration stays for write / repair / maintenance scenarios.
 */

function _stage7FastBuildResponse_(success, message, result, context, warnings, meta) {
  if (typeof buildStage4Response_ === 'function') {
    return buildStage4Response_(
      !!success,
      message || '',
      success ? null : (message || 'Операцію не виконано'),
      result,
      [],
      Object.assign({
        scenario: context && context.scenario || '',
        affectedSheets: meta && meta.affectedSheets || [],
        affectedEntities: meta && meta.affectedEntities || [],
        appliedChangesCount: 0,
        skippedChangesCount: 0,
        partial: false,
        retrySafe: true,
        lockUsed: false,
        lockRequired: false
      }, meta || {}),
      null,
      context || null,
      Array.isArray(warnings) ? warnings : []
    );
  }

  return {
    success: !!success,
    message: String(message || ''),
    error: success ? null : String(message || 'Операцію не виконано'),
    data: {
      result: result === undefined ? null : result,
      changes: [],
      meta: Object.assign({}, meta || {}),
      diagnostics: null
    },
    context: context || null,
    warnings: Array.isArray(warnings) ? warnings : []
  };
}

function _stage7FastContext_(scenario, routeName, publicApiMethod) {
  return {
    scenario: String(scenario || ''),
    routeName: routeName || '',
    publicApiMethod: publicApiMethod || '',
    fastPath: true
  };
}

function _stage7FastDescriptor_() {
  return (typeof AccessControl_ === 'object' && AccessControl_ && typeof AccessControl_.describe === 'function')
    ? AccessControl_.describe({ includeSensitiveDebug: false })
    : {
        role: 'guest',
        enabled: false,
        knownUser: false,
        registered: false,
        reason: { code: 'access.unavailable', message: 'AccessControl_ недоступний' },
        reasonString: 'AccessControl_ недоступний'
      };
}

function _stage7FastListMonthsCore_() {
  const ss = SpreadsheetApp.getActive();
  const months = ss.getSheets()
    .map(function(sheet) { return sheet.getName(); })
    .filter(function(name) { return /^\d{2}$/.test(name); })
    .sort();
  return {
    months: months,
    current: getBotMonthSheetName_()
  };
}

function apiStage7GetAccessDescriptorLite() {
  const descriptor = _stage7FastDescriptor_();
  return _stage7FastBuildResponse_(
    true,
    descriptor && descriptor.isAdmin ? 'Роль доступу визначено' : 'Доступ визначено',
    descriptor,
    _stage7FastContext_('getAccessDescriptorLite', 'sidebar.bootstrapAccess', 'apiStage7GetAccessDescriptorLite'),
    [],
    { affectedSheets: [appGetCore('ACCESS_SHEET', 'ACCESS')] }
  );
}

function apiStage7BootstrapSidebar() {
  const descriptor = _stage7FastDescriptor_();
  const monthsInfo = _stage7FastListMonthsCore_();

  return _stage7FastBuildResponse_(
    true,
    'Sidebar bootstrap готовий',
    {
      access: descriptor,
      months: monthsInfo.months,
      current: monthsInfo.current
    },
    _stage7FastContext_('bootstrapSidebar', 'sidebar.bootstrap', 'apiStage7BootstrapSidebar'),
    [],
    { affectedSheets: monthsInfo.months.slice() }
  );
}

function apiStage7GetMonthsList() {
  const result = _stage7FastListMonthsCore_();
  return _stage7FastBuildResponse_(
    true,
    'Місяці завантажено',
    result,
    _stage7FastContext_('listMonths', 'sidebar.getMonths', 'apiStage7GetMonthsList'),
    [],
    { affectedSheets: result.months.slice() }
  );
}

function apiStage7GetSidebarData(dateStr) {
  const info = validateDatePayload_({ date: dateStr || _todayStr_() }, 'date');
  const sidebar = PersonsRepository_.getSidebarPersonnel(info.payload.dateStr || info.payload.date);
  return _stage7FastBuildResponse_(
    true,
    'Дані дня завантажено',
    sidebar,
    _stage7FastContext_('loadCalendarDay', 'sidebar.loadCalendarDay', 'apiStage7GetSidebarData'),
    [],
    { affectedSheets: [sidebar.month || getBotMonthSheetName_()] }
  );
}

function apiStage7GetSendPanelData() {
  if (typeof AccessEnforcement_ === 'object' && AccessEnforcement_.assertCanUseSendPanel) {
    AccessEnforcement_.assertCanUseSendPanel('getSendPanelData', {});
  }

  const rows = SendPanelRepository_.readRows();
  const stats = SendPanelRepository_.buildStats(rows);
  const panelMeta = typeof SendPanelRepository_.getPanelMetadata === 'function'
    ? (SendPanelRepository_.getPanelMetadata() || {})
    : {};

  return _stage7FastBuildResponse_(
    true,
    'SEND_PANEL перечитано',
    {
      rows: rows,
      stats: stats,
      month: panelMeta.month || getBotMonthSheetName_(),
      date: panelMeta.date || ''
    },
    _stage7FastContext_('getSendPanelData', 'sidebar.getSendPanelData', 'apiStage7GetSendPanelData'),
    typeof _stage7BuildSendPanelWarnings_ === 'function' ? _stage7BuildSendPanelWarnings_(stats) : [],
    { affectedSheets: [CONFIG.SEND_PANEL_SHEET, panelMeta.month || getBotMonthSheetName_()] }
  );
}

function apiStage7SwitchBotToMonth(monthSheetName) {
  return Stage7UseCases_.switchBotToMonth({ month: monthSheetName || '' });
}

function apiGenerateSendPanelForDate(options) {
  return Stage7UseCases_.generateSendPanelForDate(options || {});
}

function apiGenerateSendPanelForRange(options) {
  return Stage7UseCases_.generateSendPanelForRange(options || {});
}

function apiMarkPanelRowsAsPending(rowNumbers, options) {
  return Stage7UseCases_.markPanelRowsAsPending(rowNumbers, options || {});
}

function apiMarkPanelRowsAsSent(rowNumbers, options) {
  return Stage7UseCases_.markPanelRowsAsSent(rowNumbers, options || {});
}

function _sanitizeFastSendPanelRows_(rowNumbers) {
  const rows = Array.isArray(rowNumbers) ? rowNumbers.map(function(value) {
    return Number(value);
  }) : [];
  const seen = {};
  return rows.filter(function(row) {
    if (!Number.isFinite(row) || row <= 0) return false;
    const key = String(row);
    if (seen[key]) return false;
    seen[key] = true;
    return true;
  });
}

function apiMarkPanelRowsAsSentFast(rowNumbers, options) {
  const opts = Object.assign({
    dryRun: false,
    returnRows: false,
    targetedVisualUpdate: true
  }, options || {});

  const rows = _sanitizeFastSendPanelRows_(rowNumbers);
  if (!rows.length) {
    throw new Error('Не передано коректні рядки SEND_PANEL');
  }

  if (typeof AccessEnforcement_ === 'object' && AccessEnforcement_.assertCanUseSendPanel) {
    AccessEnforcement_.assertCanUseSendPanel('markPanelRowsAsSentFast', { rowNumbers: rows });
  }

  const result = SendPanelRepository_.markRowsAsSent(rows, opts);

  return {
    success: true,
    message: 'Позначено ' + (Array.isArray(result.updatedRows) ? result.updatedRows.length : 0) + ' рядків',
    warnings: [],
    context: {
      route: 'sidebar.markPanelRowsAsSentFast',
      scenario: 'markPanelRowsAsSentFast',
      fastPath: true
    },
    data: {
      result: {
        rows: Array.isArray(result.rows) ? result.rows : [],
        updatedRows: Array.isArray(result.updatedRows) ? result.updatedRows : [],
        stats: result.stats || {},
        month: '',
        date: ''
      },
      meta: {}
    }
  };
}

function apiMarkPanelRowsAsUnsent(rowNumbers, options) {
  return Stage7UseCases_.markPanelRowsAsUnsent(rowNumbers, options || {});
}

function apiSendPendingRows(options) {
  return Stage7UseCases_.sendPendingRows(options || {});
}

function apiBuildDaySummary(dateStr) {
  return Stage7UseCases_.buildDaySummary({ date: dateStr || _todayStr_() });
}

function apiBuildDetailedSummary(dateStr) {
  return Stage7UseCases_.buildDetailedSummary({ date: dateStr || _todayStr_() });
}

function apiOpenPersonCard(callsign, dateStr) {
  const info = validatePersonLookupPayload_({
    callsign: callsign || '',
    date: dateStr || _todayStr_()
  });

  if (typeof AccessEnforcement_ === 'object' && AccessEnforcement_.assertCanOpenPersonCard) {
    AccessEnforcement_.assertCanOpenPersonCard(info.payload.callsign || '', info.payload.dateStr || info.payload.date || '');
  }

  const person = PersonsRepository_.getPersonByCallsign(info.payload.callsign, info.payload.dateStr || info.payload.date);
  const warnings = person.phone ? [] : ['Для бійця не знайдено телефон'];

  return _stage7FastBuildResponse_(
    true,
    'Картку бійця зібрано',
    person,
    _stage7FastContext_('openPersonCard', 'sidebar.openPersonCard', 'apiOpenPersonCard'),
    warnings,
    { affectedSheets: [person.sheet || getBotMonthSheetName_()], affectedEntities: [person.callsign || person.fio || ''] }
  );
}

function apiLoadCalendarDay(dateStr) {
  return apiStage7GetSidebarData(dateStr || _todayStr_());
}

function apiCheckVacationsAndBirthdays(dateStr) {
  const info = validateDatePayload_({ date: dateStr || _todayStr_() }, 'date');
  if (typeof AccessEnforcement_ === 'object' && AccessEnforcement_.assertCanUseWorkingActions) {
    AccessEnforcement_.assertCanUseWorkingActions('checkVacationsAndBirthdays', { requestedDate: info.payload.dateStr || info.payload.date || '' });
  }

  const targetDate = DateUtils_.parseUaDate(info.payload.dateStr || info.payload.date) || new Date();
  const vacations = runVacationEngine_(targetDate) || {};
  const birthdays = runBirthdayEngine_(targetDate) || {};

  return _stage7FastBuildResponse_(
    true,
    'Перевірку відпусток і ДН виконано',
    {
      date: info.payload.dateStr || info.payload.date,
      vacations: vacations,
      birthdays: birthdays
    },
    _stage7FastContext_('checkVacationsAndBirthdays', 'sidebar.checkVacationsAndBirthdays', 'apiCheckVacationsAndBirthdays'),
    [],
    { affectedSheets: [getBotMonthSheetName_(), CONFIG.PHONES_SHEET] }
  );
}

function apiStage7CreateNextMonth(options) {
  return Stage7UseCases_.createNextMonth(options || {});
}

function apiRunReconciliation(options) {
  return Stage7UseCases_.runReconciliation(options || {});
}
