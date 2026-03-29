/**
 * AccessE2ETests.gs — minimal dry-run E2E checks for access and key-rotation policy.
 */

function runAccessSecurityE2ETests_(options) {
  const opts = options || {};
  const report = {
    ok: true,
    stage: (typeof getProjectBundleMetadata_ === 'function' ? getProjectBundleMetadata_().stageVersion : '7.1.2-final-clean'),
    ts: new Date().toISOString(),
    dryRun: opts.dryRun !== false,
    checks: []
  };

  function push(name, fn) {
    try {
      const details = fn();
      report.checks.push({ name: name, status: 'OK', details: details || 'OK' });
    } catch (error) {
      report.ok = false;
      report.checks.push({ name: name, status: 'FAIL', details: error && error.message ? error.message : String(error) });
    }
  }

  push('descriptor exposes rotation policy fields', function() {
    const descriptor = AccessControl_.describe();
    if (!descriptor || typeof descriptor !== 'object') throw new Error('descriptor missing');
    if (!('rotationPolicy' in descriptor)) throw new Error('rotationPolicy missing');
    if (!('migrationModeEnabled' in descriptor)) throw new Error('migrationModeEnabled missing');
    if (!('allowedActions' in descriptor)) throw new Error('allowedActions missing');
    return 'descriptor-rotation-contract-ok';
  });

  push('viewer may open only own card', function() {
    const viewer = { role: 'viewer', enabled: true, registered: true, personCallsign: 'ALFA' };
    if (!AccessEnforcement_.canOpenPersonCard(viewer, 'ALFA')) throw new Error('viewer own card should be allowed');
    if (AccessEnforcement_.canOpenPersonCard(viewer, 'BRAVO')) throw new Error('viewer чужа картка не повинна відкриватися');
    return 'viewer-self-card-ok';
  });

  push('viewer cannot use detailed summary or send panel', function() {
    const viewer = { role: 'viewer', enabled: true, registered: true, personCallsign: 'ALFA' };
    if (AccessEnforcement_.canUseDetailedSummary(viewer)) throw new Error('viewer detailed summary should be denied');
    if (AccessEnforcement_.canUseSendPanel(viewer)) throw new Error('viewer send panel should be denied');
    return 'viewer-restrictions-ok';
  });

  push('operator gets working access', function() {
    const operator = { role: 'operator', enabled: true, registered: true };
    if (!AccessEnforcement_.canUseWorkingActions(operator)) throw new Error('operator working actions should be allowed');
    if (!AccessEnforcement_.canUseDetailedSummary(operator)) throw new Error('operator detailed summary should be allowed');
    if (!AccessEnforcement_.canUseSendPanel(operator)) throw new Error('operator send panel should be allowed');
    return 'operator-working-access-ok';
  });


  push('guest stays locked out of person cards and send panel', function() {
    const guest = { role: 'guest', enabled: true, registered: false };
    if (AccessEnforcement_.canOpenPersonCard(guest, 'ALFA')) throw new Error('guest person card should be denied');
    if (AccessEnforcement_.canUseSendPanel(guest)) throw new Error('guest send panel should be denied');
    return 'guest-restrictions-ok';
  });

  push('viewer may use day summary but not admin tools', function() {
    const viewer = { role: 'viewer', enabled: true, registered: true, personCallsign: 'ALFA' };
    if (!AccessEnforcement_.canUseDaySummary(viewer)) throw new Error('viewer day summary should be allowed');
    const actions = AccessControl_.listAllowedActionsForRole('viewer');
    if (actions.indexOf('admin.users') !== -1) throw new Error('viewer must not receive admin.users');
    return 'viewer-day-summary-ok';
  });

  push('sysadmin owns technical maintenance actions', function() {
    const actions = AccessControl_.listAllowedActionsForRole('sysadmin');
    ['maintenance.protections', 'maintenance.repair', 'maintenance.triggers'].forEach(function(action) {
      if (actions.indexOf(action) === -1) throw new Error('sysadmin missing ' + action);
    });
    return 'sysadmin-maintenance-ok';
  });

  push('maintainer/admin/sysadmin/owner allowed-actions map is present', function() {
    ['maintainer', 'admin', 'sysadmin', 'owner'].forEach(function(role) {
      const actions = AccessControl_.listAllowedActionsForRole(role);
      if (!Array.isArray(actions) || !actions.length) throw new Error('allowedActions missing for ' + role);
    });
    return 'role-actions-map-ok';
  });

  return report;
}
