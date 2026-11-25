(function () {
  "use strict";

  function getTelegramWebApp() {
    if (!window.Telegram || !window.Telegram.WebApp) {
      return null;
    }
    return window.Telegram.WebApp;
  }

  window.RayonTelegramBridge = {
    getSnapshot: function () {
      var app = getTelegramWebApp();
      if (!app) {
        return JSON.stringify({
          available: false,
          platform: "browser",
          version: "",
          initData: "",
          viewportHeight: 0,
          viewportStableHeight: 0,
          isExpanded: false
        });
      }

      try {
        app.ready();
        app.expand();
      } catch (_error) {
        // The game remains usable if an optional WebApp UI method is unavailable.
      }

      return JSON.stringify({
        available: true,
        platform: String(app.platform || "unknown"),
        version: String(app.version || ""),
        initData: String(app.initData || ""),
        viewportHeight: Number(app.viewportHeight || 0),
        viewportStableHeight: Number(app.viewportStableHeight || 0),
        isExpanded: Boolean(app.isExpanded)
      });
    }
  };
})();
