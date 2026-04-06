function _diagHasRouteApi_(fnName) {
  var target = String(fnName || '').trim();
  if (!target) return false;

  try {
    if (typeof getStage6ARouteByApiMethod_ === 'function') {
      return !!getStage6ARouteByApiMethod_(target);
    }
  } catch (_) {}

  try {
    if (typeof listStage6ARoutes_ === 'function') {
      return (listStage6ARoutes_() || []).some(function(item) {
        return item && item.publicApiMethod === target;
      });
    }
  } catch (_) {}

  try {
    if (typeof getRoutingRegistry_ === 'function') {
      var routes = getRoutingRegistry_();
      if (Array.isArray(routes)) {
        return routes.some(function(item) { return item && item.publicApiMethod === target; });
      }
      if (routes && typeof routes === 'object') {
        return Object.keys(routes).some(function(key) {
          return routes[key] && routes[key].publicApiMethod === target;
        });
      }
    }
  } catch (_) {}

  return false;
}
