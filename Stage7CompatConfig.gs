/**
 * Stage7CompatConfig.gs — canonical Stage 7A runtime/safety feature flags.
 */

var STAGE7A_CONFIG = (typeof STAGE7A_CONFIG !== 'undefined' && STAGE7A_CONFIG) ? STAGE7A_CONFIG : null;

function buildStage6AConfig_() {
  return Object.freeze({
    VERSION: '6A.0.0-hardening',
    SAFETY_TTL_SEC: appGetSafetyTtlSec(),
    ACTIVE_RUNTIME_MARKER: appGetCore('ACTIVE_RUNTIME_MARKER', 'stage7-sidebar-runtime'),
    FEATURE_FLAGS: Object.freeze({
      routingRegistry: appGetFlag('routingRegistry', true),
      safetyRegistry: appGetFlag('safetyRegistry', true),
      enrichedWriteContract: appGetFlag('enrichedWriteContract', true),
      hybridJobRuntimePolicy: appGetFlag('hybridJobRuntimePolicy', true),
      stage7ADomainTests: appGetFlag('stage7ADomainTests', true),
      fullVerboseDiagnostics: appGetFlag('fullVerboseDiagnostics', true)
    })
  });
}

function getStage6AConfig_() {
  if (!STAGE7A_CONFIG || typeof STAGE7A_CONFIG !== 'object' || !STAGE7A_CONFIG.FEATURE_FLAGS) {
    STAGE7A_CONFIG = buildStage6AConfig_();
  }
  return STAGE7A_CONFIG;
}

STAGE7A_CONFIG = getStage6AConfig_();

function stage7AGetFeatureFlag_(flagName, defaultValue) {
  if (!flagName) return !!defaultValue;
  const flags = getStage6AConfig_().FEATURE_FLAGS || {};
  if (Object.prototype.hasOwnProperty.call(flags, flagName)) return !!flags[flagName];
  return !!defaultValue;
}