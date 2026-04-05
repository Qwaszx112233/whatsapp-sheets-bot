/**
 * Stage7ServerApi.gs — canonical Stage 7 application API.
 *
 * Stage 7 is the only canonical application surface in this baseline.
 * Historical Stage 4 aliases live in Stage7CompatibilityApi.gs.
 */

function _listMonthSheetNamesFast_() {
  const ss = SpreadsheetApp.getActive();
  return ss.getSheets()
    .map(function(sheet) { return sheet.getName(); })
    .filter(function(name) { return /^\d{2}$/.test(name); })
    .sort();
}

function _buildStage7PanelPayloadFast_() {
  const rows = SendPanelRepository_.readRows();
  const stats = SendPanelRepository_.buildStats(rows);
  const panelMeta = typeof SendPanelRepository_.getPanelMetadata === 'function'
    ? (SendPanelRepository_.getPanelMetadata() || {})
    : { month: getBotMonthSheetName_(), date: '' };

  return {
    result: {
      rows: rows,
      stats: stats,
      month: panelMeta.month || getBotMonthSheetName_(),
      date: panelMeta.date || ''
    },
    meta: {
      stats: stats,
      fastPath: true
    }
  };
}

function apiStage7GetMonthsList() {
  return apiExecute_('apiStage7GetMonthsList', { route: 'sidebar.monthsList' }, function() {
    const months = _listMonthSheetNamesFast_();
    const current = getBotMonthSheetName_();
    return okResponse_({
      result: {
        months: months,
        current: current
      },
      meta: {
        fastPath: true
      }
    }, 'Місяці завантажено', {
      route: 'sidebar.monthsList',
      fastPath: true
    });
  });
}

function _buildStage7SidebarDayPayloadFast_(dateStr) {
  const info = validateDatePayload_({ date: dateStr || _todayStr_() }, 'date');
  const sidebar = PersonsRepository_.getSidebarPersonnel(info.dateStr);
  return {
    dateInfo: info,
    result: sidebar,
    meta: {
      fastPath: true,
      count: Array.isArray(sidebar && sidebar.personnel) ? sidebar.personnel.length : 0
    }
  };
}

function _buildStage7PersonCardPayloadFast_(callsign, dateStr) {
  const info = validatePersonLookupPayload_({
    callsign: callsign || '',
    date: dateStr || _todayStr_()
  });

  if (typeof AccessEnforcement_ === 'object' && AccessEnforcement_.assertCanOpenPersonCard) {
    AccessEnforcement_.assertCanOpenPersonCard(info.payload.callsign || '', info.payload.dateStr || info.payload.date || '');
  }

  const person = PersonsRepository_.getPersonByCallsign(info.payload.callsign, info.payload.dateStr || info.payload.date);
  const warnings = person && person.phone ? [] : ['Для бійця не знайдено телефон'];

  return {
    lookup: info,
    result: person,
    warnings: warnings,
    meta: {
      fastPath: true,
      callsign: person && person.callsign ? person.callsign : info.payload.callsign,
      sheet: person && person.sheet ? person.sheet : ''
    }
  };
}

function apiStage7GetSidebarData(dateStr) {
  return apiExecute_('apiStage7GetSidebarData', { route: 'sidebar.loadCalendarDay' }, function() {
    const payload = _buildStage7SidebarDayPayloadFast_(dateStr || _todayStr_());
    return okResponse_(payload.result, 'Дані дня завантажено', {
      route: 'sidebar.loadCalendarDay',
      fastPath: true,
      requestedDate: payload.dateInfo.dateStr
    }, []);
  });
}

function apiStage7GetSendPanelData() {
  return apiExecute_('apiStage7GetSendPanelData', { route: 'sidebar.getSendPanelData' }, function() {
    if (typeof AccessEnforcement_ === 'object' && AccessEnforcement_.assertCanUseSendPanel) {
      AccessEnforcement_.assertCanUseSendPanel('getSendPanelData', {});
    }

    const payload = _buildStage7PanelPayloadFast_();
    const warnings = typeof _stage7BuildSendPanelWarnings_ === 'function'
      ? _stage7BuildSendPanelWarnings_(payload.result.stats || {})
      : [];

    return okResponse_(payload, 'SEND_PANEL перечитано', {
      route: 'sidebar.getSendPanelData',
      fastPath: true
    }, warnings);
  });
}

function apiStage7GetAccessDescriptorLite() {
  return apiExecute_('apiStage7GetAccessDescriptorLite', { route: 'sidebar.accessDescriptorLite' }, function() {
    const descriptor = (typeof AccessControl_ === 'object' && AccessControl_.describe)
      ? AccessControl_.describe({ includeSensitiveDebug: false })
      : { role: 'guest', knownUser: false, reason: { message: 'AccessControl_ недоступний', code: 'access.unavailable' } };

    return okResponse_(descriptor, descriptor && descriptor.isAdmin ? 'Роль доступу визначено' : 'Доступ визначено', {
      route: 'sidebar.accessDescriptorLite'
    });
  });
}

function apiStage7BootstrapSidebar() {
  return apiExecute_('apiStage7BootstrapSidebar', { route: 'sidebar.bootstrap' }, function() {
    const descriptor = (typeof AccessControl_ === 'object' && AccessControl_.describe)
      ? AccessControl_.describe({ includeSensitiveDebug: false })
      : { role: 'guest', knownUser: false, reason: { message: 'AccessControl_ недоступний', code: 'access.unavailable' } };

    const ss = SpreadsheetApp.getActive();
    const months = ss.getSheets()
      .map(function(sheet) { return sheet.getName(); })
      .filter(function(name) { return /^\d{2}$/.test(name); })
      .sort();

    const current = getBotMonthSheetName_();
    const panelMeta = (typeof SendPanelRepository_ === 'object' && SendPanelRepository_.getPanelMetadata)
      ? (SendPanelRepository_.getPanelMetadata() || {})
      : {};
    const panelSheet = typeof DataAccess_ === 'object' && DataAccess_.getSheet
      ? DataAccess_.getSheet('SEND_PANEL', null, false)
      : null;
    const dataStartRow = Number(CONFIG && CONFIG.SEND_PANEL_DATA_START_ROW || 3) || 3;
    const rowCount = panelSheet ? Math.max(0, Number(panelSheet.getLastRow() || 0) - (dataStartRow - 1)) : 0;

    return okResponse_({
      access: descriptor,
      months: months,
      current: current,
      panel: {
        month: panelMeta.month || current || '',
        date: panelMeta.date || '',
        hasMetadata: !!panelMeta.hasMetadata,
        rowCount: rowCount,
        hasRows: rowCount > 0
      }
    }, 'Sidebar bootstrap prepared', { route: 'sidebar.bootstrap' });
  });
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
  return apiExecute_('apiOpenPersonCard', { route: 'sidebar.openPersonCard' }, function() {
    const payload = _buildStage7PersonCardPayloadFast_(callsign || '', dateStr || _todayStr_());
    return okResponse_(payload.result, 'Картку бійця зібрано', {
      route: 'sidebar.openPersonCard',
      fastPath: true,
      callsign: payload.meta.callsign || ''
    }, payload.warnings || []);
  });
}

function apiLoadCalendarDay(dateStr) {
  return apiStage7GetSidebarData(dateStr || _todayStr_());
}

function apiCheckVacationsAndBirthdays(dateStr) {
  return Stage7UseCases_.checkVacationsAndBirthdays({ date: dateStr || _todayStr_() });
}

function apiStage7CreateNextMonth(options) {
  return Stage7UseCases_.createNextMonth(options || {});
}

function apiRunReconciliation(options) {
  return Stage7UseCases_.runReconciliation(options || {});
}
