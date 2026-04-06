function runStage5FullVerboseDiagnostics_(options) {
  var base = runStage5FullDiagnostics_(options || {});
  var hardening = runStage6AHardeningDiagnostics_({ mode: 'stage7-hardening' });
  return _diagBuildReport_(
    _diagMergeChecks_(base.checks || [], hardening.checks || []),
    'full-verbose',
    (base.ok && hardening.ok) ? (_releaseStageLabel_() + ' verbose diagnostics OK') : (_releaseStageLabel_() + ' verbose diagnostics потребують уваги')
  );
}
