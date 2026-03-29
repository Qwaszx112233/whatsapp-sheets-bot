/**
 * AccessEnforcement.gs — viewer self-card restrictions, summary/send-panel gates,
 * and access violation alerts.
 */

var AccessEnforcement_ = AccessEnforcement_ || (function() {
  function _nowText_() {
    return Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'Etc/GMT', 'yyyy-MM-dd HH:mm:ss');
  }

  function _normCallsign_(value) {
    return String(value || '').trim().toUpperCase();
  }

  function _descriptor_() {
    return (typeof AccessControl_ === 'object' && AccessControl_.describe)
      ? AccessControl_.describe()
      : { role: 'guest', isAdmin: false, isOperator: false, isMaintainer: false, enabled: true, registered: false, source: 'fallback', personCallsign: '' };
  }

  function _roleLabel_(role) {
    var map = { guest: 'Гість', viewer: 'Перегляд', operator: 'Оператор', maintainer: 'Редактор', admin: 'Адмін', sysadmin: 'Сис. адмін', owner: 'Власник' };
    return map[String(role || 'guest').trim().toLowerCase()] || 'Гість';
  }

  function _notificationEmails_() {
    if (typeof AccessControl_ !== 'object' || !AccessControl_.listNotificationEmails) return [];
    return AccessControl_.listNotificationEmails();
  }

  function _appendAlert_(severity, message, details) {
    if (typeof AlertsRepository_ !== 'object' || !AlertsRepository_.appendAlert) return;
    AlertsRepository_.appendAlert({
      timestamp: new Date(),
      jobName: 'accessViolation',
      severity: severity || 'warning',
      message: message || '',
      details: details || {}
    });
  }

  function _appendAudit_(record) {
    try {
      if (typeof Stage4AuditTrail_ !== 'object' || !Stage4AuditTrail_.record) return;
      Stage4AuditTrail_.record({
        timestamp: new Date(),
        scenario: 'accessViolation',
        level: 'SECURITY',
        status: 'BLOCKED',
        initiator: record.email || record.currentKey || record.role || '',
        affectedSheets: [appGetCore('ALERTS_SHEET', 'ALERTS_LOG')],
        affectedEntities: [record.action || 'accessViolation'],
        warnings: [record.message || 'Порушення доступу'],
        payload: record.details || {},
        diagnostics: record,
        message: record.message || 'Зафіксовано порушення доступу'
      });
    } catch (_) {}
  }

  function _appendCompactLog_(record) {
    try {
      if (typeof LogsRepository_ !== 'object' || !LogsRepository_.writeBatch) return;
      LogsRepository_.writeBatch([{
        timestamp: new Date(),
        reportDateStr: _nowText_(),
        sheet: appGetCore('ALERTS_SHEET', 'ALERTS_LOG'),
        cell: record.action || '',
        fio: record.displayName || record.personCallsign || record.roleLabel || '',
        phone: '',
        code: 'ACCESS_VIOLATION',
        service: record.source || '',
        place: '',
        tasks: '',
        message: record.message || '',
        link: ''
      }]);
    } catch (_) {}
  }

  function _sendMail_(subject, body) {
    var recipients = _notificationEmails_();
    if (!recipients.length) return { sent: false, recipients: [] };
    MailApp.sendEmail(recipients.join(','), subject, body);
    return { sent: true, recipients: recipients };
  }

  function _roleAtLeast_(descriptor, roleName) {
    var access = descriptor || _descriptor_();
    if (access.enabled === false) return false;
    if (typeof AccessControl_ === 'object' && AccessControl_.ROLE_ORDER) {
      var current = AccessControl_.ROLE_ORDER[String(access.role || 'guest').toLowerCase()] || 0;
      var need = AccessControl_.ROLE_ORDER[String(roleName || 'guest').toLowerCase()] || 0;
      return current >= need;
    }
    var fallback = { guest: 0, viewer: 1, operator: 2, maintainer: 3, admin: 4, sysadmin: 5, owner: 6 };
    return (fallback[String(access.role || 'guest').toLowerCase()] || 0) >= (fallback[String(roleName || 'guest').toLowerCase()] || 0);
  }

  function reportViolation(actionName, details, descriptorOpt) {
    var descriptor = descriptorOpt || _descriptor_();
    var action = String(actionName || 'unknownAction').trim() || 'unknownAction';
    var info = Object.assign({}, details || {});
    var role = String(descriptor.role || 'guest').trim().toLowerCase() || 'guest';
    var roleLabel = _roleLabel_(role);
    var message = 'Спроба доступу без прав: ' + action + ' (' + roleLabel + ')';
    var record = {
      timestamp: _nowText_(),
      action: action,
      role: role,
      roleLabel: roleLabel,
      source: descriptor.source || '',
      registered: !!descriptor.registered,
      enabled: descriptor.enabled !== false,
      email: descriptor.email || '',
      displayName: descriptor.displayName || '',
      currentKey: descriptor.currentKey || '',
      personCallsign: descriptor.personCallsign || '',
      outcome: info.blocked === false ? 'warning' : 'blocked',
      message: message,
      details: info
    };

    _appendAlert_(info.bestEffort ? 'warning' : 'critical', message, record);
    _appendAudit_(record);
    _appendCompactLog_(record);

    var body = [
      'WAPB SECURITY ALERT',
      '===================',
      'Дата і час: ' + record.timestamp,
      'Тип порушення: ' + action,
      'Роль: ' + roleLabel,
      'Display name: ' + (record.displayName || 'не визначено'),
      'User key: ' + (record.currentKey || 'не визначено'),
      'Email: ' + (record.email || 'не визначено'),
      'Джерело: ' + (record.source || 'не визначено'),
      'Спроба: ' + (info.requestedAction || info.violation || action),
      'Підсумок: ' + (record.outcome === 'blocked' ? 'заблоковано / відхилено' : 'best-effort warning'),
      'Позивний користувача: ' + (record.personCallsign || 'не задано'),
      '',
      'Деталі:',
      stage4SafeStringify_(info || {}, 9000)
    ].join('\n');

    var mailResult = { sent: false, recipients: [] };
    if (!info.suppressEmail) {
      try {
        mailResult = _sendMail_('WAPB SECURITY ALERT: ' + action, body);
      } catch (error) {
        _appendAlert_('error', 'Не вдалося надіслати email-сповіщення про порушення доступу', {
          action: action,
          error: error && error.message ? error.message : String(error),
          original: record
        });
      }
    }

    return {
      success: true,
      message: message,
      alertLogged: true,
      auditLogged: true,
      logWritten: true,
      emailSent: !!mailResult.sent,
      recipients: mailResult.recipients || [],
      data: record
    };
  }

  function canOpenPersonCard(descriptor, callsign) {
    var access = descriptor || _descriptor_();
    var target = _normCallsign_(callsign);
    if (!target) return false;
    if (access.enabled === false) return false;
    if (_roleAtLeast_(access, 'operator')) return true;
    if (String(access.role || 'guest').toLowerCase() !== 'viewer') return false;
    var own = _normCallsign_(access.personCallsign || '');
    return !!own && own === target;
  }

  function assertCanOpenPersonCard(callsign, dateStr, descriptorOpt) {
    var descriptor = descriptorOpt || _descriptor_();
    if (canOpenPersonCard(descriptor, callsign)) return descriptor;
    reportViolation('openPersonCardDenied', {
      requestedAction: 'openPersonCard',
      requestedCallsign: String(callsign || ''),
      requestedDate: String(dateStr || ''),
      violation: 'viewer-card-access',
      blocked: true
    }, descriptor);
    throw new Error('Недостатньо прав для відкриття цієї картки.');
  }

  function canUseDaySummary(descriptor) {
    var access = descriptor || _descriptor_();
    return _roleAtLeast_(access, 'viewer');
  }

  function assertCanUseDaySummary(dateStr, descriptorOpt) {
    var descriptor = descriptorOpt || _descriptor_();
    if (canUseDaySummary(descriptor)) return descriptor;
    reportViolation('daySummaryDenied', {
      requestedAction: 'buildDaySummary',
      requestedDate: String(dateStr || ''),
      violation: 'guest-day-summary-access',
      blocked: true
    }, descriptor);
    throw new Error('Недостатньо прав для зведення дня.');
  }

  function canUseDetailedSummary(descriptor) {
    var access = descriptor || _descriptor_();
    return _roleAtLeast_(access, 'operator');
  }

  function assertCanUseDetailedSummary(dateStr, descriptorOpt) {
    var descriptor = descriptorOpt || _descriptor_();
    if (canUseDetailedSummary(descriptor)) return descriptor;
    reportViolation('detailedSummaryDenied', {
      requestedAction: 'buildDetailedSummary',
      requestedDate: String(dateStr || ''),
      violation: 'viewer-detailed-summary-access',
      blocked: true
    }, descriptor);
    throw new Error('Недостатньо прав для детального зведення.');
  }

  function canUseWorkingActions(descriptor) {
    var access = descriptor || _descriptor_();
    return _roleAtLeast_(access, 'operator');
  }

  function assertCanUseWorkingActions(actionName, details, descriptorOpt) {
    var descriptor = descriptorOpt || _descriptor_();
    if (canUseWorkingActions(descriptor)) return descriptor;
    reportViolation('workingActionDenied', Object.assign({
      requestedAction: String(actionName || 'workingAction'),
      violation: 'working-action-access',
      blocked: true
    }, details || {}), descriptor);
    throw new Error('Недостатньо прав для цієї робочої дії.');
  }

  function canUseSendPanel(descriptor) {
    return canUseWorkingActions(descriptor);
  }

  function assertCanUseSendPanel(actionName, details, descriptorOpt) {
    var descriptor = descriptorOpt || _descriptor_();
    if (canUseSendPanel(descriptor)) return descriptor;
    reportViolation('sendPanelDenied', Object.assign({
      requestedAction: String(actionName || 'SEND_PANEL'),
      violation: 'send-panel-access',
      blocked: true
    }, details || {}), descriptor);
    throw new Error('Недостатньо прав для SEND_PANEL.');
  }

  function describeEditActorByEmail(email) {
    var normalized = (typeof AccessControl_ === 'object' && AccessControl_.normalizeEmail)
      ? AccessControl_.normalizeEmail(email)
      : String(email || '').trim().toLowerCase();
    var row = (typeof AccessControl_ === 'object' && AccessControl_.getAccessRowByEmail)
      ? AccessControl_.getAccessRowByEmail(normalized)
      : null;
    if (!row) {
      return {
        email: normalized,
        role: 'guest',
        enabled: true,
        knownUser: !!normalized,
        registered: false,
        isAdmin: false,
        isOperator: false,
        isMaintainer: false,
        source: normalized ? 'ACCESS-email-unregistered' : 'edit-user-unavailable',
        personCallsign: ''
      };
    }
    var role = String(row.role || 'guest').toLowerCase();
    return {
      email: normalized || row.email || '',
      role: role,
      enabled: row.enabled !== false,
      knownUser: !!normalized,
      registered: true,
      isAdmin: ['admin', 'sysadmin', 'owner'].indexOf(role) !== -1 && row.enabled !== false,
      isOperator: ['operator', 'maintainer', 'admin', 'sysadmin', 'owner'].indexOf(role) !== -1 && row.enabled !== false,
      isMaintainer: ['maintainer', 'admin', 'sysadmin', 'owner'].indexOf(role) !== -1 && row.enabled !== false,
      source: row.source || 'ACCESS',
      personCallsign: row.personCallsign || ''
    };
  }

  return {
    reportViolation: reportViolation,
    canOpenPersonCard: canOpenPersonCard,
    assertCanOpenPersonCard: assertCanOpenPersonCard,
    canUseDaySummary: canUseDaySummary,
    assertCanUseDaySummary: assertCanUseDaySummary,
    canUseDetailedSummary: canUseDetailedSummary,
    assertCanUseDetailedSummary: assertCanUseDetailedSummary,
    canUseWorkingActions: canUseWorkingActions,
    assertCanUseWorkingActions: assertCanUseWorkingActions,
    canUseSendPanel: canUseSendPanel,
    assertCanUseSendPanel: assertCanUseSendPanel,
    describeEditActorByEmail: describeEditActorByEmail
  };
})();

function stage7ReportAccessViolation(actionName, details) {
  return AccessEnforcement_.reportViolation(actionName, details || {});
}

function stage7SecurityAuditOnEdit(e) {
  try {
    var sheet = e && e.range ? e.range.getSheet() : null;
    var sheetName = sheet ? sheet.getName() : '';
    var userEmail = '';
    try { userEmail = e && e.user && e.user.getEmail ? String(e.user.getEmail() || '') : ''; } catch (_) {}
    var actor = AccessEnforcement_.describeEditActorByEmail(userEmail);
    var role = String(actor.role || 'guest').toLowerCase();
    var protectedSheets = ['ACCESS', 'ALERTS_LOG', 'JOB_RUNTIME_LOG', 'AUDIT_LOG', 'OPS_LOG', 'ACTIVE_OPERATIONS', 'CHECKPOINTS'];
    var editedProtectedSheet = protectedSheets.indexOf(sheetName) !== -1;
    var shouldAlert = actor.knownUser
      ? (role === 'guest' || role === 'viewer' || !actor.registered || (editedProtectedSheet && !actor.isAdmin))
      : false;
    if (!shouldAlert) return;
    AccessEnforcement_.reportViolation('sheetEditDeniedOrSuspicious', {
      requestedAction: 'sheetEdit',
      sheet: sheetName,
      a1Notation: e && e.range && e.range.getA1Notation ? e.range.getA1Notation() : '',
      oldValue: e && typeof e.oldValue !== 'undefined' ? e.oldValue : '',
      newValue: e && typeof e.value !== 'undefined' ? e.value : '',
      editedProtectedSheet: editedProtectedSheet,
      editorEmailFromEvent: userEmail || '',
      blocked: editedProtectedSheet && !actor.isAdmin
    }, actor);
  } catch (_) {}
}

function stage7SecurityAuditOnChange(e) {
  try {
    var source = e && e.source ? e.source : SpreadsheetApp.getActive();
    var userEmail = '';
    try { userEmail = e && e.user && e.user.getEmail ? String(e.user.getEmail() || '') : ''; } catch (_) {}
    var actor = AccessEnforcement_.describeEditActorByEmail(userEmail);
    var changeType = e && e.changeType ? String(e.changeType) : 'OTHER';
    var shouldAlert = (!actor.isAdmin) || !actor.knownUser || !actor.registered;
    if (!shouldAlert) return;
    AccessEnforcement_.reportViolation('sheetStructureChangeDeniedOrSuspicious', {
      requestedAction: 'sheetStructureChange',
      spreadsheetId: source && source.getId ? source.getId() : '',
      spreadsheetName: source && source.getName ? source.getName() : '',
      changeType: changeType,
      editorEmailFromEvent: userEmail || '',
      bestEffort: !actor.knownUser,
      suppressEmail: !actor.knownUser,
      blocked: !actor.isAdmin
    }, actor);
  } catch (_) {}
}
