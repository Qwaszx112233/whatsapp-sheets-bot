/**
 * Simple spreadsheet triggers for ACCESS UI helpers and best-effort security audit.
 */
function onEdit(e) {
  try {
    if (typeof AccessControl_ === 'object' && AccessControl_.handleAccessSheetEdit) {
      AccessControl_.handleAccessSheetEdit(e);
    }
  } catch (error) {
    try { console.error('onEdit ACCESS helper error:', error); } catch (_) {}
  }

  try {
    if (typeof stage7SecurityAuditOnEdit === 'function') {
      stage7SecurityAuditOnEdit(e);
    }
  } catch (error) {
    try { console.error('onEdit security audit error:', error); } catch (_) {}
  }
}

function onChange(e) {
  try {
    if (typeof stage7SecurityAuditOnChange === 'function') {
      stage7SecurityAuditOnChange(e);
    }
  } catch (error) {
    try { console.error('onChange security audit error:', error); } catch (_) {}
  }
}
