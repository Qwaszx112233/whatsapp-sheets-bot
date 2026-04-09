/**
 * DeprecatedRegistry.gs — canonical deprecated helper registry for the active baseline.
 */

const DEPRECATED_REGISTRY_ = Object.freeze([
  {
    name: '_parseUaDate_',
    replacement: 'DateUtils_.parseUaDate()',
    scope: 'shared helpers',
    status: 'deprecated-helper-wrapper',
    uiAllowed: false,
    risk: 'low',
    sunset: 'remove after full helper cleanup'
  },
  {
    name: 'normalizeDate_',
    replacement: 'DateUtils_.normalizeDate()',
    scope: 'shared helpers',
    status: 'deprecated-helper-wrapper',
    uiAllowed: false,
    risk: 'low',
    sunset: 'remove after full helper cleanup'
  },
  {
    name: '_parseDate_',
    replacement: 'DateUtils_.parseDateAny() / _veParseDate_()',
    scope: 'shared helpers',
    status: 'deprecated-helper-wrapper',
    uiAllowed: false,
    risk: 'low',
    sunset: 'remove after full helper cleanup'
  },
  {
    name: 'escapeHtml_',
    replacement: 'HtmlUtils_.escapeHtml()',
    scope: 'shared helpers',
    status: 'deprecated-helper-wrapper',
    uiAllowed: false,
    risk: 'low',
    sunset: 'remove after full helper cleanup'
  },
  {
    name: '_escapeHtml_',
    replacement: 'HtmlUtils_.escapeHtml()',
    scope: 'shared helpers',
    status: 'deprecated-helper-wrapper',
    uiAllowed: false,
    risk: 'low',
    sunset: 'remove after full helper cleanup'
  }
]);

function _stage7EnrichCompatibilityRecord_(item) {
  const record = Object.assign({}, item || {});
  const status = String(record.status || '').trim() || 'deprecated-helper-wrapper';

  const usageScope = record.scope && String(record.scope).indexOf('helpers') !== -1
    ? 'shared helpers'
    : record.uiAllowed
      ? 'spreadsheet ui'
      : 'manual editor run';

  let sunsetStatus = 'sunset planned';
  if (status === 'canonical') sunsetStatus = 'canonical';
  else if (status.indexOf('deprecated') !== -1) sunsetStatus = 'deprecated';

  return Object.assign(record, {
    migrationStatus: record.migrationStatus || (sunsetStatus === 'canonical' ? 'migrated' : 'pending'),
    usageScope: record.usageScope || usageScope,
    sunsetStatus: record.sunsetStatus || sunsetStatus,
    removalCondition: record.removalCondition || record.sunset || '',
    removableAfterMigration: record.removableAfterMigration === true || sunsetStatus === 'deprecated'
  });
}

function getDeprecatedRegistry_() {
  return DEPRECATED_REGISTRY_.map(_stage7EnrichCompatibilityRecord_);
}

function getCompatibilitySunsetReport_() {
  const items = getDeprecatedRegistry_();
  const counts = {};

  items.forEach(function(item) {
    const key = item.sunsetStatus || 'unknown';
    counts[key] = (counts[key] || 0) + 1;
  });

  return {
    total: items.length,
    counts: counts,
    missingSunsetMarkers: items.filter(function(item) {
      return !String(item.removalCondition || '').trim();
    }).length,
    items: items
  };
}