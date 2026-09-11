"use strict";
(() => {
  const $ = (s) => document.querySelector(s);
  const hud = $("#hud");
  const vehicleCard = $("#vehicle-card");
  const speedArc = $("#speed-arc");
  const speedValue = $("#speed-value");
  const gearValue = $("#gear-value");
  const speedUnit = $("#speed-unit");

  const clamp = (v, min, max) => Math.max(min, Math.min(max, Number(v) || 0));
  const setText = (id, value) => { const el = document.getElementById(id); if (el) el.textContent = value; };

  function renderGeometry(data) {
    const { left, top, width, height } = data;
    if (![left, top, width, height].every(Number.isFinite) ||
        left < 0 || top < 0 || width <= 0 || height <= 0 ||
        left + width > 1.001 || top + height > 1.001) return;
    // Fractions survive CEF pixel scaling. Do not independently clamp/resize
    // the frame: these are the exact on-screen bounds of the native mask.
    const style = document.documentElement.style;
    style.setProperty("--map-left", `${left * 100}vw`);
    style.setProperty("--map-top", `${top * 100}vh`);
    style.setProperty("--map-width", `${width * 100}vw`);
    style.setProperty("--map-height", `${height * 100}vh`);
  }

  function renderMap(data) {
    setText("heading-value", String(data.heading ?? 0).padStart(3, "0"));
    setText("heading-cardinal", data.cardinal || "N");
    setText("zone-name", (data.zone || "Los Santos").toUpperCase());
    setText("street-name", data.street || "");
    setText("crossing-name", data.crossing ? data.crossing.toUpperCase() : "");
  }

  function renderVehicle(data) {
    const show = !!data.show;
    vehicleCard.classList.toggle("hidden", !show);
    if (!show) return;

    speedValue.textContent = String(Math.round(clamp(data.speed, 0, 999))).padStart(3, "0");
    gearValue.textContent = data.gear || "N";
    speedUnit.textContent = data.unit || "MPH";
    speedArc.style.setProperty("--progress", clamp(data.rpm, 0, 1).toFixed(3));

    setText("fuel-value", `${Math.round(clamp(data.fuel, 0, 100))}%`);
    setText("engine-value", `${Math.round(clamp(data.engine, 0, 100))}%`);
    setText("seatbelt-value", data.seatbelt ? "ON" : "OFF");
    setText("lights-value", data.lights ? "ON" : "OFF");
    setText("handbrake-value", data.handbrake ? "ON" : "OFF");

    document.getElementById("fuel-value")?.classList.toggle("low", clamp(data.fuel, 0, 100) < 20);
    document.getElementById("engine-value")?.classList.toggle("low", clamp(data.engine, 0, 100) < 30);
    document.getElementById("seatbelt-value")?.classList.toggle("on", !!data.seatbelt);
  }
  window.addEventListener("message", (event) => {
    const msg = event.data || {};
    if (msg.type === "visibility") hud.classList.toggle("hidden", !msg.data?.visible);
    else if (msg.type === "mapGeometry") renderGeometry(msg.data || {});
    else if (msg.type === "map") renderMap(msg.data || {});
    else if (msg.type === "vehicle") renderVehicle(msg.data || {});
  });
  if (typeof GetParentResourceName === "function") {
    fetch(`https://${GetParentResourceName()}/ready`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: "{}"
    }).catch(() => {});
  }
})();
