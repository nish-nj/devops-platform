(function () {
  "use strict";
  var $ = function (id) { return document.getElementById(id); };
  var setText = function (id, t) { var e = $(id); if (e) { e.textContent = t; } };

  function getJSON(url) {
    return fetch(url, { cache: "no-store" }).then(function (r) {
      if (!r.ok) { throw new Error(url + " returned HTTP " + r.status); }
      return r.json();
    });
  }

  function setBar(id, pct, warnAt) {
    var e = $(id);
    if (!e) { return; }
    e.style.width = Math.max(0, Math.min(100, pct)) + "%";
    e.style.background = pct >= warnAt ? "var(--bad)" : "var(--ok)";
  }

  function fmtUptime(sec) {
    var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
    return d + "d " + h + "h " + m + "m";
  }

  function health() {
    var b = $("health-badge");
    fetch("healthz", { cache: "no-store" }).then(function (r) {
      if (!r.ok) { throw new Error("bad status"); }
      b.className = "badge badge-ok"; b.textContent = "Application healthy";
    }).catch(function () {
      b.className = "badge badge-bad"; b.textContent = "Health check failed";
    });
  }

  function deployment() {
    getJSON("status.json").then(function (s) {
      setText("d-version", s.version || "n/a");
      setText("d-sha", (s.commit || "n/a").slice(0, 12));
      setText("d-built", s.built_at || "n/a");
      setText("d-env", s.environment || "n/a");
    }).catch(function () {
      ["d-version", "d-sha", "d-built", "d-env"].forEach(function (i) { setText(i, "unavailable"); });
    });
  }

  function monitoring() {
    getJSON("monitor/status.json").then(function (m) {
      var t = m.thresholds || {};
      setText("m-cpu", m.cpu_percent + " %");
      setText("m-mem", m.mem_percent + " %  (" + m.mem_used_mb + " / " + m.mem_total_mb + " MB)");
      setText("m-disk", m.disk_percent + " %");
      setText("m-free", m.disk_free_gb + " GB");
      setText("m-up", fmtUptime(m.uptime_seconds));
      setText("m-time", m.timestamp);
      setBar("m-cpu-bar", m.cpu_percent, t.cpu || 80);
      setBar("m-mem-bar", m.mem_percent, t.mem || 80);
      setBar("m-disk-bar", m.disk_percent, t.disk || 80);
      setText("mon-note", "Live data written by monitoring/monitor.sh (via cron) on the server.");
      var w = $("m-warn");
      if (m.warnings && m.warnings.length) { w.hidden = false; w.textContent = "Warnings: " + m.warnings.join("; "); }
      else { w.hidden = true; }
    }).catch(function () {
      setText("mon-note", "No monitoring data yet. It appears on the EC2 server after monitor.sh runs with STATUS_FILE set (see docs/DEPLOYMENT.md). Locally this is expected.");
    });
  }

  health(); deployment(); monitoring();
  setInterval(monitoring, 30000);
})();
