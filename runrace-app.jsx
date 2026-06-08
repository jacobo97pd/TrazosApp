import { useState, useEffect, useRef, useCallback } from "react";

const ZONES = [
  { id: 1, name: "Parque Retiro", owner: null, club: null, color: null, polygon: [[40.4153, -3.6844], [40.4189, -3.6821], [40.4201, -3.6874], [40.4178, -3.6901], [40.4153, -3.6844]], points: 120, size: "grande" },
  { id: 2, name: "Malasaña", owner: "Carlos R.", club: "MadRunners", color: "#FF4D4D", polygon: [[40.4268, -3.7050], [40.4289, -3.7018], [40.4302, -3.7041], [40.4281, -3.7065], [40.4268, -3.7050]], points: 80, size: "mediana" },
  { id: 3, name: "Lavapiés", owner: null, club: null, color: null, polygon: [[40.4099, -3.7023], [40.4124, -3.6998], [40.4139, -3.7012], [40.4121, -3.7045], [40.4099, -3.7023]], points: 95, size: "mediana" },
  { id: 4, name: "Chamberí", owner: "SkyRunners", club: "SkyRunners", color: "#00C2FF", polygon: [[40.4328, -3.6975], [40.4355, -3.6940], [40.4368, -3.6965], [40.4342, -3.7001], [40.4328, -3.6975]], points: 110, size: "grande" },
  { id: 5, name: "La Latina", owner: null, club: null, color: null, polygon: [[40.4119, -3.7089], [40.4142, -3.7064], [40.4158, -3.7080], [40.4134, -3.7108], [40.4119, -3.7089]], points: 70, size: "pequeña" },
  { id: 6, name: "Chueca", owner: "Alex M.", club: null, color: "#FFB800", polygon: [[40.4234, -3.6978], [40.4256, -3.6952], [40.4270, -3.6970], [40.4248, -3.7000], [40.4234, -3.6978]], points: 85, size: "mediana" },
];

const LEADERBOARD = [
  { rank: 1, name: "SkyRunners", type: "club", zones: 12, km: 342, avatar: "SR" },
  { rank: 2, name: "MadRunners", type: "club", zones: 9, km: 287, avatar: "MR" },
  { rank: 3, name: "Carlos R.", type: "solo", zones: 6, km: 201, avatar: "CR" },
  { rank: 4, name: "Alex M.", type: "solo", zones: 4, km: 158, avatar: "AM" },
  { rank: 5, name: "Tú", type: "solo", zones: 2, km: 89, avatar: "YO" },
];

const ACTIVITIES = [
  { id: 1, date: "Hoy", zone: "Parque Retiro", km: 7.2, time: "38:12", captured: true },
  { id: 2, date: "Ayer", zone: "Ninguna", km: 5.1, time: "26:44", captured: false },
  { id: 3, date: "Lun", zone: "Chueca", km: 8.9, time: "47:30", captured: true },
];

export default function App() {
  const [screen, setScreen] = useState("splash");
  const [activeTab, setActiveTab] = useState("map");
  const [running, setRunning] = useState(false);
  const [runTime, setRunTime] = useState(0);
  const [runDist, setRunDist] = useState(0);
  const [selectedZone, setSelectedZone] = useState(null);
  const [myClub, setMyClub] = useState("MadRunners");
  const [capturedZones, setCapturedZones] = useState([1]);
  const [showCapture, setShowCapture] = useState(false);
  const [runPath, setRunPath] = useState([]);
  const [pathClosed, setPathClosed] = useState(false);
  const timerRef = useRef(null);

  useEffect(() => {
    const t = setTimeout(() => setScreen("onboard"), 2000);
    return () => clearTimeout(t);
  }, []);

  useEffect(() => {
    if (running) {
      timerRef.current = setInterval(() => {
        setRunTime(t => t + 1);
        setRunDist(d => d + 0.0028);
      }, 1000);
    } else {
      clearInterval(timerRef.current);
    }
    return () => clearInterval(timerRef.current);
  }, [running]);

  const fmt = (s) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;

  const startRun = () => {
    setRunning(true);
    setRunTime(0);
    setRunDist(0);
    setRunPath([]);
    setPathClosed(false);
    setActiveTab("run");
  };

  const closePath = () => {
    if (runPath.length > 3) {
      setPathClosed(true);
    } else {
      const simPath = [
        [0.2, 0.3], [0.5, 0.15], [0.8, 0.3], [0.7, 0.6], [0.4, 0.7], [0.2, 0.3]
      ];
      setRunPath(simPath);
      setPathClosed(true);
    }
  };

  const captureZone = () => {
    setRunning(false);
    setShowCapture(true);
    setCapturedZones(prev => [...prev, 3]);
    setTimeout(() => { setShowCapture(false); setActiveTab("map"); }, 3000);
  };

  if (screen === "splash") return <SplashScreen />;
  if (screen === "onboard") return <OnboardScreen onDone={() => setScreen("main")} />;

  return (
    <div style={{ fontFamily: "'DM Sans', 'Helvetica Neue', Arial, sans-serif", background: "var(--bg)", minHeight: "100vh", maxWidth: 390, margin: "0 auto", position: "relative", overflow: "hidden" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700&family=DM+Mono:wght@500&display=swap');
        :root {
          --bg: #0A0A0F;
          --surface: #13131A;
          --surface2: #1C1C26;
          --border: rgba(255,255,255,0.08);
          --text: #F0F0F5;
          --muted: rgba(240,240,245,0.45);
          --accent: #FF4D6D;
          --accent2: #00E5FF;
          --green: #39FF7A;
          --gold: #FFB800;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: var(--bg); }
        .tab-btn { background: none; border: none; cursor: pointer; display: flex; flex-direction: column; align-items: center; gap: 3px; padding: 8px 12px; color: var(--muted); font-size: 10px; font-family: inherit; font-weight: 500; transition: color 0.2s; }
        .tab-btn.active { color: var(--accent2); }
        .tab-btn i { font-size: 22px; }
        .pulse { animation: pulse 2s infinite; }
        @keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:0.7;transform:scale(0.97)} }
        .zone-pill { padding: 3px 10px; border-radius: 20px; font-size: 11px; font-weight: 600; }
        .capture-flash { animation: flash 0.5s ease-in-out 3; }
        @keyframes flash { 0%,100%{opacity:1} 50%{opacity:0} }
        .run-counter { font-family: 'DM Mono', monospace; }
        .glow-text { text-shadow: 0 0 20px var(--accent2); }
        .card { background: var(--surface); border: 1px solid var(--border); border-radius: 16px; }
        .btn-primary { background: var(--accent); color: #fff; border: none; border-radius: 12px; padding: 14px 24px; font-family: inherit; font-size: 15px; font-weight: 600; cursor: pointer; width: 100%; transition: opacity 0.2s; }
        .btn-primary:active { opacity: 0.85; }
        .btn-outline { background: transparent; color: var(--text); border: 1px solid var(--border); border-radius: 12px; padding: 14px 24px; font-family: inherit; font-size: 15px; font-weight: 500; cursor: pointer; width: 100%; transition: all 0.2s; }
        .btn-outline:active { background: var(--surface2); }
        .slide-up { animation: slideUp 0.3s ease-out; }
        @keyframes slideUp { from { transform: translateY(20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        .avatar { display: flex; align-items: center; justify-content: center; border-radius: 50%; font-weight: 700; font-size: 12px; }
      `}</style>

      {activeTab === "map" && <MapScreen zones={ZONES} capturedZones={capturedZones} selectedZone={selectedZone} setSelectedZone={setSelectedZone} onStartRun={startRun} myClub={myClub} />}
      {activeTab === "run" && <RunScreen running={running} runTime={runTime} runDist={runDist} fmt={fmt} onStart={startRun} onStop={() => setRunning(false)} onClose={closePath} onCapture={captureZone} pathClosed={pathClosed} runPath={runPath} setRunPath={setRunPath} />}
      {activeTab === "ranking" && <RankingScreen leaderboard={LEADERBOARD} myClub={myClub} />}
      {activeTab === "profile" && <ProfileScreen capturedZones={capturedZones} activities={ACTIVITIES} myClub={myClub} />}

      <BottomNav activeTab={activeTab} setActiveTab={setActiveTab} running={running} />

      {showCapture && <CaptureOverlay />}
    </div>
  );
}

function SplashScreen() {
  return (
    <div style={{ background: "#0A0A0F", minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div style={{ width: 80, height: 80, borderRadius: 22, background: "linear-gradient(135deg, #FF4D6D, #FF8C00)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 36 }}>
        🏃
      </div>
      <div style={{ color: "#F0F0F5", fontSize: 32, fontWeight: 700, fontFamily: "'DM Sans', sans-serif", letterSpacing: -1 }}>RunRace</div>
      <div style={{ color: "rgba(240,240,245,0.45)", fontSize: 14, fontFamily: "'DM Sans', sans-serif" }}>Conquista tu ciudad</div>
      <div style={{ marginTop: 40, width: 40, height: 4, borderRadius: 2, background: "rgba(255,255,255,0.1)", overflow: "hidden" }}>
        <div style={{ height: "100%", background: "#FF4D6D", borderRadius: 2, animation: "load 2s linear forwards" }} />
      </div>
      <style>{`@keyframes load { from{width:0%} to{width:100%} }`}</style>
    </div>
  );
}

function OnboardScreen({ onDone }) {
  const [step, setStep] = useState(0);
  const steps = [
    { icon: "🗺️", title: "Conquista zonas", desc: "Cierra el cerco de cualquier área de la ciudad mientras corres y captúrala para ti o tu club." },
    { icon: "🏃‍♂️", title: "Corre y captura", desc: "El GPS rastrea tu ruta. Cuando formes un polígono cerrado encima de una zona, ¡es tuya!" },
    { icon: "⚔️", title: "Compite", desc: "Defiende tus zonas, arrebata las de otros y lleva a tu RunClub a lo más alto del ranking." },
  ];
  const s = steps[step];
  return (
    <div style={{ background: "#0A0A0F", minHeight: "100vh", fontFamily: "'DM Sans', sans-serif", display: "flex", flexDirection: "column", padding: "60px 24px 40px" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", gap: 24 }}>
        <div style={{ fontSize: 72, lineHeight: 1 }}>{s.icon}</div>
        <div>
          <div style={{ color: "#F0F0F5", fontSize: 26, fontWeight: 700, marginBottom: 12, letterSpacing: -0.5 }}>{s.title}</div>
          <div style={{ color: "rgba(240,240,245,0.55)", fontSize: 15, lineHeight: 1.6, maxWidth: 280 }}>{s.desc}</div>
        </div>
        <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
          {steps.map((_, i) => (
            <div key={i} style={{ width: i === step ? 20 : 8, height: 8, borderRadius: 4, background: i === step ? "#FF4D6D" : "rgba(255,255,255,0.15)", transition: "all 0.3s" }} />
          ))}
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {step < 2 ? (
          <button className="btn-primary" onClick={() => setStep(s => s + 1)}>Siguiente</button>
        ) : (
          <>
            <button className="btn-primary" onClick={onDone}>Conectar con Strava</button>
            <button className="btn-outline" onClick={onDone}>Continuar sin Strava</button>
          </>
        )}
      </div>
    </div>
  );
}

function MapScreen({ zones, capturedZones, selectedZone, setSelectedZone, onStartRun, myClub }) {
  const [filter, setFilter] = useState("all");
  const svgRef = useRef(null);

  const centerLat = 40.42;
  const centerLon = -3.70;
  const scale = 4000;

  const toSVG = (lat, lon) => {
    const x = (lon - centerLon) * scale + 190;
    const y = -(lat - centerLat) * scale + 280;
    return [x, y];
  };

  const getZonePoints = (zone) => zone.polygon.map(([lat, lon]) => toSVG(lat, lon).join(",")).join(" ");

  const getZoneColor = (zone) => {
    if (capturedZones.includes(zone.id)) return "#FF4D6D";
    if (zone.color) return zone.color;
    return "rgba(255,255,255,0.07)";
  };

  const isMyZone = (zone) => capturedZones.includes(zone.id);

  return (
    <div style={{ background: "var(--bg)", minHeight: "100vh", paddingBottom: 80 }}>
      <div style={{ padding: "16px 16px 8px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div>
          <div style={{ color: "var(--muted)", fontSize: 11, fontWeight: 500, textTransform: "uppercase", letterSpacing: 1 }}>RunRace</div>
          <div style={{ color: "var(--text)", fontSize: 20, fontWeight: 700, letterSpacing: -0.5 }}>Madrid</div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <div style={{ background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 10, padding: "6px 12px", color: "var(--accent2)", fontSize: 12, fontWeight: 600 }}>
            ⚡ {capturedZones.length} zonas
          </div>
        </div>
      </div>

      <div style={{ margin: "8px 16px", display: "flex", gap: 8, overflowX: "auto", paddingBottom: 4 }}>
        {["all", "libres", "rivales", "mías"].map(f => (
          <button key={f} onClick={() => setFilter(f)} style={{ background: filter === f ? "var(--accent)" : "var(--surface)", border: "1px solid var(--border)", borderRadius: 20, padding: "5px 14px", color: filter === f ? "#fff" : "var(--muted)", fontSize: 12, fontWeight: 600, cursor: "pointer", whiteSpace: "nowrap", flexShrink: 0 }}>
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>

      <div style={{ margin: "8px 16px", borderRadius: 18, overflow: "hidden", border: "1px solid var(--border)", background: "#111118", position: "relative" }}>
        <svg ref={svgRef} viewBox="0 0 380 480" style={{ width: "100%", display: "block" }}>
          <defs>
            <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
              <path d="M 20 0 L 0 0 0 20" fill="none" stroke="rgba(255,255,255,0.03)" strokeWidth="0.5" />
            </pattern>
          </defs>
          <rect width="380" height="480" fill="url(#grid)" />
          {[...Array(8)].map((_, i) => (
            <circle key={i} cx="190" cy="280" r={40 + i * 35} fill="none" stroke="rgba(255,255,255,0.02)" strokeWidth="0.5" />
          ))}

          {zones.map(zone => (
            <g key={zone.id} onClick={() => setSelectedZone(selectedZone?.id === zone.id ? null : zone)} style={{ cursor: "pointer" }}>
              <polygon
                points={getZonePoints(zone)}
                fill={getZoneColor(zone)}
                fillOpacity={isMyZone(zone) ? 0.35 : zone.color ? 0.25 : 0.12}
                stroke={getZoneColor(zone)}
                strokeWidth={selectedZone?.id === zone.id ? 2 : 1}
                strokeOpacity={0.8}
              />
              {(() => {
                const pts = zone.polygon.map(([lat, lon]) => toSVG(lat, lon));
                const cx = pts.reduce((s, p) => s + p[0], 0) / pts.length;
                const cy = pts.reduce((s, p) => s + p[1], 0) / pts.length;
                return (
                  <text x={cx} y={cy} textAnchor="middle" dominantBaseline="central" fill={isMyZone(zone) ? "#FF4D6D" : zone.color || "rgba(255,255,255,0.5)"} fontSize="9" fontWeight="600" fontFamily="DM Sans, sans-serif">{zone.name.split(" ")[0]}</text>
                );
              })()}
            </g>
          ))}

          <circle cx="190" cy="280" r="5" fill="var(--accent2)" />
          <circle cx="190" cy="280" r="10" fill="var(--accent2)" fillOpacity="0.2" />
          <circle cx="190" cy="280" r="18" fill="var(--accent2)" fillOpacity="0.08" />
        </svg>

        <div style={{ position: "absolute", top: 10, right: 10, display: "flex", flexDirection: "column", gap: 6 }}>
          {["+", "−", "⊕"].map((btn, i) => (
            <button key={i} style={{ width: 32, height: 32, background: "rgba(19,19,26,0.9)", border: "1px solid var(--border)", borderRadius: 8, color: "var(--text)", fontSize: 16, cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}>{btn}</button>
          ))}
        </div>
      </div>

      {selectedZone ? (
        <div className="slide-up" style={{ margin: "12px 16px", background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 16, padding: "16px" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
            <div>
              <div style={{ color: "var(--text)", fontSize: 17, fontWeight: 700 }}>{selectedZone.name}</div>
              <div style={{ color: "var(--muted)", fontSize: 12, marginTop: 2 }}>Zona {selectedZone.size} · {selectedZone.points} pts</div>
            </div>
            {capturedZones.includes(selectedZone.id) ? (
              <span className="zone-pill" style={{ background: "rgba(255,77,109,0.15)", color: "#FF4D6D" }}>Tuya ✓</span>
            ) : selectedZone.owner ? (
              <span className="zone-pill" style={{ background: "rgba(255,255,255,0.07)", color: "var(--muted)" }}>De {selectedZone.owner}</span>
            ) : (
              <span className="zone-pill" style={{ background: "rgba(57,255,122,0.12)", color: "var(--green)" }}>Libre</span>
            )}
          </div>
          {!capturedZones.includes(selectedZone.id) && (
            <button className="btn-primary" style={{ marginTop: 12, background: "var(--accent)", padding: "10px 20px", borderRadius: 10, fontSize: 14 }} onClick={onStartRun}>
              🏃 Ir a capturar
            </button>
          )}
        </div>
      ) : (
        <div style={{ margin: "12px 16px", display: "flex", gap: 10 }}>
          <div className="card" style={{ flex: 1, padding: "12px 14px" }}>
            <div style={{ color: "var(--muted)", fontSize: 11 }}>Zonas libres</div>
            <div style={{ color: "var(--green)", fontSize: 20, fontWeight: 700 }}>{zones.filter(z => !z.owner && !capturedZones.includes(z.id)).length}</div>
          </div>
          <div className="card" style={{ flex: 1, padding: "12px 14px" }}>
            <div style={{ color: "var(--muted)", fontSize: 11 }}>Zonas rivales</div>
            <div style={{ color: "#FF4D4D", fontSize: 20, fontWeight: 700 }}>{zones.filter(z => z.owner && !capturedZones.includes(z.id)).length}</div>
          </div>
          <div className="card" style={{ flex: 1, padding: "12px 14px" }}>
            <div style={{ color: "var(--muted)", fontSize: 11 }}>Mis zonas</div>
            <div style={{ color: "var(--accent2)", fontSize: 20, fontWeight: 700 }}>{capturedZones.length}</div>
          </div>
        </div>
      )}

      <div style={{ margin: "4px 16px 0", display: "flex", alignItems: "center", gap: 8 }}>
        <div style={{ width: 10, height: 10, borderRadius: 2, background: "#FF4D6D" }} /><span style={{ color: "var(--muted)", fontSize: 11 }}>Tuyas</span>
        <div style={{ width: 10, height: 10, borderRadius: 2, background: "#00C2FF" }} /><span style={{ color: "var(--muted)", fontSize: 11 }}>Rivales</span>
        <div style={{ width: 10, height: 10, borderRadius: 2, background: "rgba(255,255,255,0.15)" }} /><span style={{ color: "var(--muted)", fontSize: 11 }}>Libres</span>
      </div>
    </div>
  );
}

function RunScreen({ running, runTime, runDist, fmt, onStart, onStop, onClose, onCapture, pathClosed, runPath, setRunPath }) {
  const canvasRef = useRef(null);
  const animRef = useRef(null);
  const pathRef = useRef([]);
  const [dotPos, setDotPos] = useState({ x: 190, y: 240 });

  useEffect(() => {
    if (!running) return;
    let angle = 0;
    const animate = () => {
      angle += 0.025;
      const radius = 50 + Math.sin(angle * 0.7) * 20;
      const nx = 190 + Math.cos(angle) * radius;
      const ny = 240 + Math.sin(angle) * radius * 0.6;
      setDotPos({ x: nx, y: ny });
      pathRef.current = [...pathRef.current, [nx / 380, ny / 340]];
      if (pathRef.current.length > 80) pathRef.current = pathRef.current.slice(-80);
      setRunPath([...pathRef.current]);
      animRef.current = requestAnimationFrame(animate);
    };
    animRef.current = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animRef.current);
  }, [running]);

  const pace = runDist > 0 ? (runTime / 60 / runDist).toFixed(2) : "—";

  return (
    <div style={{ background: "var(--bg)", minHeight: "100vh", paddingBottom: 80 }}>
      <div style={{ padding: "20px 16px 12px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div style={{ color: "var(--text)", fontSize: 20, fontWeight: 700, letterSpacing: -0.5 }}>Carrera activa</div>
        {running && (
          <div style={{ display: "flex", alignItems: "center", gap: 6, background: "rgba(255,77,109,0.15)", borderRadius: 20, padding: "4px 12px" }}>
            <div style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--accent)" }} className="pulse" />
            <span style={{ color: "var(--accent)", fontSize: 12, fontWeight: 600 }}>EN VIVO</span>
          </div>
        )}
      </div>

      <div style={{ margin: "0 16px 16px", background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 18, padding: "20px", display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
        <div style={{ textAlign: "center" }}>
          <div className="run-counter" style={{ color: "var(--text)", fontSize: 26, fontWeight: 500 }}>{fmt(runTime)}</div>
          <div style={{ color: "var(--muted)", fontSize: 10, marginTop: 2, textTransform: "uppercase", letterSpacing: 0.5 }}>Tiempo</div>
        </div>
        <div style={{ textAlign: "center", borderLeft: "1px solid var(--border)", borderRight: "1px solid var(--border)" }}>
          <div className="run-counter" style={{ color: "var(--accent2)", fontSize: 26, fontWeight: 500 }}>{runDist.toFixed(2)}</div>
          <div style={{ color: "var(--muted)", fontSize: 10, marginTop: 2, textTransform: "uppercase", letterSpacing: 0.5 }}>km</div>
        </div>
        <div style={{ textAlign: "center" }}>
          <div className="run-counter" style={{ color: "var(--text)", fontSize: 26, fontWeight: 500 }}>{pace}</div>
          <div style={{ color: "var(--muted)", fontSize: 10, marginTop: 2, textTransform: "uppercase", letterSpacing: 0.5 }}>min/km</div>
        </div>
      </div>

      <div style={{ margin: "0 16px 16px", background: "#111118", border: "1px solid var(--border)", borderRadius: 18, overflow: "hidden", position: "relative" }}>
        <svg viewBox="0 0 380 340" style={{ width: "100%", display: "block" }}>
          <defs>
            <pattern id="runGrid" width="20" height="20" patternUnits="userSpaceOnUse">
              <path d="M 20 0 L 0 0 0 20" fill="none" stroke="rgba(255,255,255,0.03)" strokeWidth="0.5" />
            </pattern>
          </defs>
          <rect width="380" height="340" fill="url(#runGrid)" />

          {runPath.length > 1 && (
            <polyline
              points={runPath.map(([px, py]) => `${px * 380},${py * 340}`).join(" ")}
              fill="none"
              stroke="#FF4D6D"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              opacity={pathClosed ? 0.5 : 1}
            />
          )}

          {pathClosed && runPath.length > 2 && (
            <polygon
              points={runPath.map(([px, py]) => `${px * 380},${py * 340}`).join(" ")}
              fill="rgba(255,77,109,0.18)"
              stroke="#FF4D6D"
              strokeWidth="2"
              strokeDasharray="6,3"
            />
          )}

          {running && (
            <>
              <circle cx={dotPos.x} cy={dotPos.y} r="14" fill="rgba(0,229,255,0.1)" />
              <circle cx={dotPos.x} cy={dotPos.y} r="8" fill="rgba(0,229,255,0.25)" />
              <circle cx={dotPos.x} cy={dotPos.y} r="5" fill="var(--accent2)" />
            </>
          )}

          {!running && runPath.length === 0 && (
            <text x="190" y="170" textAnchor="middle" fill="rgba(255,255,255,0.2)" fontSize="13" fontFamily="DM Sans, sans-serif">Inicia la carrera para ver tu ruta</text>
          )}

          {pathClosed && (
            <g>
              <rect x="120" y="140" width="140" height="36" rx="8" fill="rgba(57,255,122,0.15)" stroke="rgba(57,255,122,0.5)" strokeWidth="1" />
              <text x="190" y="162" textAnchor="middle" fill="#39FF7A" fontSize="13" fontWeight="600" fontFamily="DM Sans, sans-serif">¡Cerco completado!</text>
            </g>
          )}
        </svg>

        {!pathClosed && running && (
          <div style={{ position: "absolute", top: 10, left: 10, background: "rgba(19,19,26,0.85)", borderRadius: 8, padding: "4px 10px", fontSize: 11, color: "var(--muted)" }}>
            GPS activo
          </div>
        )}
      </div>

      <div style={{ padding: "0 16px", display: "flex", flexDirection: "column", gap: 10 }}>
        {!running ? (
          <button className="btn-primary" style={{ background: "var(--accent)" }} onClick={onStart}>
            🏃 Iniciar carrera
          </button>
        ) : (
          <div style={{ display: "flex", gap: 10 }}>
            <button onClick={onStop} style={{ flex: 1, background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 12, padding: 14, color: "var(--text)", fontSize: 14, fontWeight: 600, cursor: "pointer", fontFamily: "inherit" }}>
              ⏸ Pausar
            </button>
            {!pathClosed ? (
              <button onClick={onClose} style={{ flex: 2, background: "rgba(0,229,255,0.12)", border: "1px solid rgba(0,229,255,0.3)", borderRadius: 12, padding: 14, color: "var(--accent2)", fontSize: 14, fontWeight: 600, cursor: "pointer", fontFamily: "inherit" }}>
                ⬡ Cerrar cerco
              </button>
            ) : (
              <button onClick={onCapture} style={{ flex: 2, background: "rgba(57,255,122,0.15)", border: "1px solid rgba(57,255,122,0.4)", borderRadius: 12, padding: 14, color: "var(--green)", fontSize: 14, fontWeight: 600, cursor: "pointer", fontFamily: "inherit" }} className="pulse">
                ✦ Capturar zona
              </button>
            )}
          </div>
        )}
      </div>

      <div style={{ margin: "16px 16px 0", padding: "14px 16px", background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 14 }}>
        <div style={{ color: "var(--muted)", fontSize: 11, marginBottom: 8, textTransform: "uppercase", letterSpacing: 0.5 }}>Cómo capturar una zona</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {[["🏃", "Corre rodeando el área que quieres capturar"], ["⬡", "Pulsa 'Cerrar cerco' cuando hayas completado el perímetro"], ["✦", "Si el polígono cubre la zona, pulsa 'Capturar'"]].map(([icon, text], i) => (
            <div key={i} style={{ display: "flex", gap: 10, alignItems: "flex-start" }}>
              <span style={{ fontSize: 14 }}>{icon}</span>
              <span style={{ color: "var(--muted)", fontSize: 12, lineHeight: 1.4 }}>{text}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function RankingScreen({ leaderboard, myClub }) {
  const [view, setView] = useState("clubs");
  return (
    <div style={{ background: "var(--bg)", minHeight: "100vh", paddingBottom: 80 }}>
      <div style={{ padding: "20px 16px 16px" }}>
        <div style={{ color: "var(--text)", fontSize: 20, fontWeight: 700, letterSpacing: -0.5, marginBottom: 16 }}>Ranking</div>
        <div style={{ display: "flex", background: "var(--surface)", borderRadius: 12, padding: 4, gap: 2 }}>
          {["clubs", "solos"].map(v => (
            <button key={v} onClick={() => setView(v)} style={{ flex: 1, padding: "8px 0", borderRadius: 9, background: view === v ? "var(--accent)" : "transparent", color: view === v ? "#fff" : "var(--muted)", border: "none", fontFamily: "inherit", fontSize: 13, fontWeight: 600, cursor: "pointer", transition: "all 0.2s" }}>
              {v === "clubs" ? "🏟 RunClubs" : "🏃 Solos"}
            </button>
          ))}
        </div>
      </div>

      <div style={{ padding: "0 16px" }}>
        {leaderboard.filter(e => view === "clubs" ? e.type === "club" : e.type === "solo").map((entry, i) => (
          <div key={entry.rank} className="slide-up" style={{ background: i === 0 ? "rgba(255,184,0,0.07)" : "var(--surface)", border: `1px solid ${i === 0 ? "rgba(255,184,0,0.3)" : "var(--border)"}`, borderRadius: 14, padding: "14px 16px", marginBottom: 10, display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 28, textAlign: "center", color: i < 3 ? ["#FFB800", "#C0C0C0", "#CD7F32"][i] : "var(--muted)", fontSize: i < 3 ? 18 : 14, fontWeight: 700 }}>
              {i < 3 ? ["🥇", "🥈", "🥉"][i] : entry.rank}
            </div>
            <div className="avatar" style={{ width: 40, height: 40, background: entry.name === "Tú" ? "rgba(255,77,109,0.2)" : "rgba(255,255,255,0.07)", color: entry.name === "Tú" ? "var(--accent)" : "var(--muted)", fontSize: 11 }}>
              {entry.avatar}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ color: entry.name === "Tú" ? "var(--accent)" : "var(--text)", fontSize: 15, fontWeight: 600 }}>{entry.name}</div>
              <div style={{ color: "var(--muted)", fontSize: 12, marginTop: 1 }}>{entry.km} km totales</div>
            </div>
            <div style={{ textAlign: "right" }}>
              <div style={{ color: "var(--accent2)", fontSize: 18, fontWeight: 700 }}>{entry.zones}</div>
              <div style={{ color: "var(--muted)", fontSize: 10 }}>zonas</div>
            </div>
          </div>
        ))}
      </div>

      <div style={{ margin: "8px 16px", background: "rgba(0,229,255,0.05)", border: "1px solid rgba(0,229,255,0.15)", borderRadius: 14, padding: "14px 16px" }}>
        <div style={{ color: "var(--accent2)", fontSize: 12, fontWeight: 600, marginBottom: 6 }}>⚡ Temporada actual</div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div style={{ color: "var(--muted)", fontSize: 12 }}>Termina en 14 días</div>
          <div style={{ background: "rgba(0,229,255,0.1)", borderRadius: 8, padding: "4px 10px", color: "var(--accent2)", fontSize: 11, fontWeight: 600 }}>Ver premios →</div>
        </div>
        <div style={{ marginTop: 10, height: 4, background: "rgba(255,255,255,0.07)", borderRadius: 2, overflow: "hidden" }}>
          <div style={{ height: "100%", width: "65%", background: "var(--accent2)", borderRadius: 2 }} />
        </div>
      </div>
    </div>
  );
}

function ProfileScreen({ capturedZones, activities, myClub }) {
  const [tab, setTab] = useState("stats");
  const badges = [
    { icon: "🏆", name: "Primera captura", desc: "Capturó su primera zona" },
    { icon: "⚡", name: "Velocista", desc: "+5km en una carrera" },
    { icon: "🌙", name: "Noctámbulo", desc: "Corrió después de las 22h" },
  ];
  return (
    <div style={{ background: "var(--bg)", minHeight: "100vh", paddingBottom: 80 }}>
      <div style={{ background: "var(--surface)", borderBottom: "1px solid var(--border)", padding: "20px 16px 16px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
          <div className="avatar" style={{ width: 60, height: 60, background: "rgba(255,77,109,0.15)", color: "var(--accent)", fontSize: 20, fontWeight: 700, borderRadius: "50%" }}>YO</div>
          <div style={{ flex: 1 }}>
            <div style={{ color: "var(--text)", fontSize: 20, fontWeight: 700 }}>Corredor</div>
            <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 4 }}>
              <div style={{ width: 8, height: 8, borderRadius: "50%", background: "#00C2FF" }} />
              <span style={{ color: "var(--muted)", fontSize: 12 }}>{myClub}</span>
            </div>
          </div>
          <div style={{ background: "rgba(255,184,0,0.12)", borderRadius: 10, padding: "6px 12px", textAlign: "center" }}>
            <div style={{ color: "var(--gold)", fontSize: 16, fontWeight: 700 }}>Nv.7</div>
            <div style={{ color: "var(--muted)", fontSize: 10 }}>Nivel</div>
          </div>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10, marginTop: 16 }}>
          {[["89 km", "Total"], [capturedZones.length + " zonas", "Capturadas"], ["3", "Rachas"]].map(([val, label]) => (
            <div key={label} style={{ background: "rgba(255,255,255,0.04)", borderRadius: 12, padding: "10px 0", textAlign: "center" }}>
              <div style={{ color: "var(--text)", fontSize: 16, fontWeight: 700 }}>{val}</div>
              <div style={{ color: "var(--muted)", fontSize: 10, marginTop: 2 }}>{label}</div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ display: "flex", margin: "16px 16px 0", background: "var(--surface)", borderRadius: 12, padding: 4, gap: 2 }}>
        {["stats", "logros", "historial"].map(t => (
          <button key={t} onClick={() => setTab(t)} style={{ flex: 1, padding: "8px 0", borderRadius: 9, background: tab === t ? "rgba(255,77,109,0.2)" : "transparent", color: tab === t ? "var(--accent)" : "var(--muted)", border: "none", fontFamily: "inherit", fontSize: 12, fontWeight: 600, cursor: "pointer" }}>
            {t.charAt(0).toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>

      <div style={{ padding: "16px 16px 0" }}>
        {tab === "stats" && (
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {[["Racha actual", "3 días", "🔥"], ["Mejor pace", "4:22 /km", "⚡"], ["Zona favorita", "Parque Retiro", "📍"], ["Club", myClub, "🏟"]].map(([label, val, icon]) => (
              <div key={label} style={{ background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 14, padding: "14px 16px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <span style={{ fontSize: 18 }}>{icon}</span>
                  <span style={{ color: "var(--muted)", fontSize: 13 }}>{label}</span>
                </div>
                <span style={{ color: "var(--text)", fontSize: 14, fontWeight: 600 }}>{val}</span>
              </div>
            ))}
          </div>
        )}

        {tab === "logros" && (
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {badges.map(b => (
              <div key={b.name} style={{ background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 14, padding: "14px 16px", display: "flex", gap: 14, alignItems: "center" }}>
                <div style={{ width: 44, height: 44, borderRadius: 12, background: "rgba(255,184,0,0.1)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 22 }}>{b.icon}</div>
                <div>
                  <div style={{ color: "var(--text)", fontSize: 14, fontWeight: 600 }}>{b.name}</div>
                  <div style={{ color: "var(--muted)", fontSize: 12, marginTop: 2 }}>{b.desc}</div>
                </div>
              </div>
            ))}
          </div>
        )}

        {tab === "historial" && (
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {activities.map(a => (
              <div key={a.id} style={{ background: "var(--surface)", border: "1px solid var(--border)", borderRadius: 14, padding: "14px 16px" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                  <div>
                    <div style={{ color: "var(--text)", fontSize: 14, fontWeight: 600 }}>{a.date} · {a.time}</div>
                    <div style={{ color: "var(--muted)", fontSize: 12, marginTop: 2 }}>{a.km} km</div>
                  </div>
                  {a.captured && (
                    <span className="zone-pill" style={{ background: "rgba(57,255,122,0.12)", color: "var(--green)" }}>✓ {a.zone}</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function CaptureOverlay() {
  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.75)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", zIndex: 100, gap: 20 }}>
      <div style={{ fontSize: 72, animation: "bounceIn 0.5s ease-out" }}>🏆</div>
      <div style={{ color: "#fff", fontSize: 28, fontWeight: 700, textAlign: "center", letterSpacing: -0.5, fontFamily: "DM Sans, sans-serif" }}>¡Zona capturada!</div>
      <div style={{ color: "rgba(255,255,255,0.6)", fontSize: 15, fontFamily: "DM Sans, sans-serif" }}>Lavapiés es tuya ahora</div>
      <div style={{ color: "var(--accent2)", fontSize: 20, fontWeight: 700, fontFamily: "DM Mono, monospace" }}>+95 pts</div>
      <style>{`@keyframes bounceIn { 0%{transform:scale(0)} 80%{transform:scale(1.1)} 100%{transform:scale(1)} }`}</style>
    </div>
  );
}

function BottomNav({ activeTab, setActiveTab, running }) {
  const tabs = [
    { id: "map", icon: "ti-map-2", label: "Mapa" },
    { id: "run", icon: "ti-run", label: running ? "En carrera" : "Correr" },
    { id: "ranking", icon: "ti-trophy", label: "Ranking" },
    { id: "profile", icon: "ti-user", label: "Perfil" },
  ];
  return (
    <div style={{ position: "fixed", bottom: 0, left: "50%", transform: "translateX(-50%)", width: "100%", maxWidth: 390, background: "rgba(13,13,20,0.95)", backdropFilter: "blur(12px)", borderTop: "1px solid rgba(255,255,255,0.07)", display: "flex", justifyContent: "space-around", alignItems: "center", padding: "8px 0 16px", zIndex: 50 }}>
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/dist/tabler-icons.min.css" />
      {tabs.map(tab => (
        <button key={tab.id} className={`tab-btn ${activeTab === tab.id ? "active" : ""}`} onClick={() => setActiveTab(tab.id)} style={{ position: "relative" }}>
          {tab.id === "run" ? (
            <div style={{ width: 50, height: 50, borderRadius: "50%", background: running ? "var(--accent)" : "rgba(255,77,109,0.15)", border: `2px solid ${running ? "var(--accent)" : "rgba(255,77,109,0.4)"}`, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: -6 }}>
              <i className={`ti ${tab.icon}`} style={{ fontSize: 22, color: running ? "#fff" : "var(--accent)" }} />
            </div>
          ) : (
            <i className={`ti ${tab.icon}`} />
          )}
          <span style={{ fontSize: tab.id === "run" ? 9 : 10 }}>{tab.label}</span>
          {tab.id === "run" && running && (
            <div style={{ position: "absolute", top: 4, right: 8, width: 8, height: 8, borderRadius: "50%", background: "var(--green)" }} className="pulse" />
          )}
        </button>
      ))}
    </div>
  );
}
