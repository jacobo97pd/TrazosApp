(function () {
  "use strict";

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  class CityCanvas {
    constructor(canvas) {
      this.canvas = canvas;
      this.ctx = canvas.getContext("2d");
      this.dpr = Math.min(window.devicePixelRatio || 1, 2);
      this.width = 0;
      this.height = 0;
      this.frame = 0;
      this.roadSeeds = [
        [[-0.1, 0.18], [0.16, 0.22], [0.44, 0.18], [0.78, 0.26], [1.12, 0.22]],
        [[-0.08, 0.42], [0.22, 0.38], [0.45, 0.47], [0.72, 0.43], [1.08, 0.52]],
        [[-0.04, 0.72], [0.22, 0.64], [0.54, 0.7], [0.84, 0.63], [1.1, 0.72]],
        [[0.12, -0.1], [0.18, 0.22], [0.26, 0.48], [0.22, 0.86], [0.28, 1.12]],
        [[0.44, -0.1], [0.48, 0.18], [0.42, 0.44], [0.5, 0.72], [0.46, 1.08]],
        [[0.76, -0.08], [0.7, 0.22], [0.8, 0.5], [0.72, 0.82], [0.84, 1.1]]
      ];
      this.routes = [
        { color: "#ff4f72", width: 7, points: [[0.12, 0.72], [0.22, 0.58], [0.38, 0.62], [0.48, 0.46], [0.62, 0.54], [0.78, 0.42]] },
        { color: "#45d6ff", width: 6, points: [[0.22, 0.28], [0.34, 0.34], [0.44, 0.28], [0.58, 0.34], [0.68, 0.28]] },
        { color: "#78f3b3", width: 6, points: [[0.72, 0.78], [0.64, 0.62], [0.76, 0.52], [0.92, 0.6], [1.04, 0.48]] }
      ];
      this.zones = [
        { color: "#f8c65c", points: [[0.62, 0.2], [0.75, 0.28], [0.72, 0.42], [0.57, 0.46], [0.5, 0.32]] },
        { color: "#78f3b3", points: [[0.22, 0.18], [0.35, 0.22], [0.38, 0.36], [0.25, 0.44], [0.14, 0.34]] },
        { color: "#45d6ff", points: [[0.42, 0.62], [0.58, 0.66], [0.6, 0.82], [0.44, 0.9], [0.32, 0.76]] }
      ];
      this.resize = this.resize.bind(this);
      this.draw = this.draw.bind(this);
      window.addEventListener("resize", this.resize, { passive: true });
      this.resize();
      this.draw(0);
    }

    resize() {
      const rect = this.canvas.getBoundingClientRect();
      this.width = Math.max(1, Math.floor(rect.width));
      this.height = Math.max(1, Math.floor(rect.height));
      this.canvas.width = Math.floor(this.width * this.dpr);
      this.canvas.height = Math.floor(this.height * this.dpr);
      this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    }

    point(raw) {
      return [raw[0] * this.width, raw[1] * this.height];
    }

    drawPolyline(points, color, width, alpha) {
      const ctx = this.ctx;
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.strokeStyle = color;
      ctx.lineWidth = width;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.beginPath();
      points.forEach((point, index) => {
        const [x, y] = this.point(point);
        if (index === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      });
      ctx.stroke();
      ctx.restore();
    }

    drawZone(zone) {
      const ctx = this.ctx;
      ctx.save();
      ctx.strokeStyle = zone.color;
      ctx.fillStyle = this.hexToRgba(zone.color, 0.12);
      ctx.lineWidth = 2;
      ctx.beginPath();
      zone.points.forEach((point, index) => {
        const [x, y] = this.point(point);
        if (index === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      });
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      ctx.restore();
    }

    pathPosition(points, progress) {
      const segments = [];
      let total = 0;

      for (let i = 0; i < points.length - 1; i += 1) {
        const a = this.point(points[i]);
        const b = this.point(points[i + 1]);
        const length = Math.hypot(b[0] - a[0], b[1] - a[1]);
        segments.push({ a, b, length });
        total += length;
      }

      let distance = (progress % 1) * total;
      for (const segment of segments) {
        if (distance <= segment.length) {
          const t = segment.length === 0 ? 0 : distance / segment.length;
          return [
            segment.a[0] + (segment.b[0] - segment.a[0]) * t,
            segment.a[1] + (segment.b[1] - segment.a[1]) * t
          ];
        }
        distance -= segment.length;
      }

      return segments.length ? segments[segments.length - 1].b : [0, 0];
    }

    hexToRgba(hex, alpha) {
      const normalized = hex.replace("#", "");
      const value = parseInt(normalized, 16);
      const r = (value >> 16) & 255;
      const g = (value >> 8) & 255;
      const b = value & 255;
      return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    }

    draw(timestamp) {
      const ctx = this.ctx;
      this.frame = timestamp || 0;
      ctx.clearRect(0, 0, this.width, this.height);

      ctx.fillStyle = "#080a10";
      ctx.fillRect(0, 0, this.width, this.height);

      this.roadSeeds.forEach((road, index) => {
        this.drawPolyline(road, index % 2 ? "rgba(255,255,255,0.11)" : "rgba(255,255,255,0.08)", index % 2 ? 7 : 4, 1);
      });

      this.zones.forEach((zone) => this.drawZone(zone));

      this.routes.forEach((route, index) => {
        this.drawPolyline(route.points, "rgba(0,0,0,0.26)", route.width + 7, 1);
        this.drawPolyline(route.points, route.color, route.width, 0.92);

        const progress = reduceMotion ? 0.42 : (timestamp / (6200 + index * 900) + index * 0.27) % 1;
        const [x, y] = this.pathPosition(route.points, progress);
        ctx.save();
        ctx.fillStyle = "#ffffff";
        ctx.shadowColor = route.color;
        ctx.shadowBlur = 24;
        ctx.beginPath();
        ctx.arc(x, y, 5.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      });

      if (!reduceMotion) {
        window.requestAnimationFrame(this.draw);
      }
    }
  }

  function initHeader() {
    const header = document.querySelector("[data-header]");
    const toggle = document.querySelector("[data-nav-toggle]");
    const menu = document.querySelector("[data-nav-menu]");

    const updateHeader = () => {
      header.classList.toggle("is-scrolled", window.scrollY > 12);
    };

    updateHeader();
    window.addEventListener("scroll", updateHeader, { passive: true });

    if (!toggle || !menu) {
      return;
    }

    toggle.addEventListener("click", () => {
      const open = !menu.classList.contains("is-open");
      menu.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", String(open));
    });

    menu.addEventListener("click", (event) => {
      if (event.target instanceof HTMLAnchorElement) {
        menu.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  function initReveal() {
    const elements = Array.from(document.querySelectorAll(".reveal"));
    if (!elements.length || reduceMotion || !("IntersectionObserver" in window)) {
      elements.forEach((element) => element.classList.add("is-visible"));
      return;
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.18, rootMargin: "0px 0px -40px" });

    elements.forEach((element) => observer.observe(element));
  }

  function initCounters() {
    const counters = Array.from(document.querySelectorAll("[data-counter]"));
    if (!counters.length) {
      return;
    }

    const animate = (node) => {
      const target = Number(node.getAttribute("data-counter") || "0");
      const duration = reduceMotion ? 1 : 1100;
      const start = performance.now();

      const tick = (now) => {
        const progress = Math.min(1, (now - start) / duration);
        const eased = 1 - Math.pow(1 - progress, 3);
        node.textContent = String(Math.round(target * eased));
        if (progress < 1) {
          window.requestAnimationFrame(tick);
        }
      };

      window.requestAnimationFrame(tick);
    };

    if (!("IntersectionObserver" in window)) {
      counters.forEach(animate);
      return;
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          animate(entry.target);
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.4 });

    counters.forEach((counter) => observer.observe(counter));
  }

  function initLeaderboard() {
    const root = document.querySelector("[data-leaderboard]");
    if (!root) {
      return;
    }

    const data = {
      clubs: {
        podium: [
          ["first", "Centro Runners", "31 zonas - 142 km"],
          ["second", "Lavapies Crew", "22 zonas - 97 km"],
          ["third", "Retiro Norte", "18 zonas - 83 km"]
        ],
        list: [
          ["Malasana Track", "15 zonas - 68 km"],
          ["Chamberi Pace", "13 zonas - 54 km"],
          ["Atocha Sprint", "11 zonas - 49 km"]
        ]
      },
      solo: {
        podium: [
          ["first", "Jacobo C.", "19 zonas - 64 km"],
          ["second", "Nerea R.", "16 zonas - 58 km"],
          ["third", "Mario V.", "14 zonas - 51 km"]
        ],
        list: [
          ["Laura G.", "12 zonas - 45 km"],
          ["Daniel P.", "10 zonas - 41 km"],
          ["Sofia M.", "9 zonas - 38 km"]
        ]
      }
    };

    const render = (mode) => {
      const board = data[mode];
      board.podium.forEach(([slot, name, score]) => {
        const nameNode = root.querySelector(`[data-rank-name="${slot}"]`);
        const scoreNode = root.querySelector(`[data-rank-score="${slot}"]`);
        if (nameNode) nameNode.textContent = name;
        if (scoreNode) scoreNode.textContent = score;
      });

      board.list.forEach(([name, score], index) => {
        const nameNode = root.querySelector(`[data-list-name="${index}"]`);
        const scoreNode = root.querySelector(`[data-list-score="${index}"]`);
        if (nameNode) nameNode.textContent = name;
        if (scoreNode) scoreNode.textContent = score;
      });
    };

    root.querySelectorAll("[data-board-tab]").forEach((button) => {
      button.addEventListener("click", () => {
        root.querySelectorAll("[data-board-tab]").forEach((tab) => {
          const active = tab === button;
          tab.classList.toggle("is-active", active);
          tab.setAttribute("aria-selected", String(active));
        });
        render(button.getAttribute("data-board-tab") || "clubs");
      });
    });
  }

  function initFaq() {
    document.querySelectorAll(".faq-item").forEach((item) => {
      const button = item.querySelector("button");
      if (!button) {
        return;
      }

      button.addEventListener("click", () => {
        const open = !item.classList.contains("is-open");
        item.classList.toggle("is-open", open);
        button.setAttribute("aria-expanded", String(open));
      });
    });
  }

  function initPointerLift() {
    if (!window.matchMedia("(pointer: fine)").matches || reduceMotion) {
      return;
    }

    document.querySelectorAll(".button, .nav-cta").forEach((element) => {
      element.addEventListener("pointermove", (event) => {
        const rect = element.getBoundingClientRect();
        const x = ((event.clientX - rect.left) / rect.width - 0.5) * 8;
        const y = ((event.clientY - rect.top) / rect.height - 0.5) * 8;
        element.style.transform = `translate(${x}px, ${y}px)`;
      });

      element.addEventListener("pointerleave", () => {
        element.style.transform = "";
      });
    });
  }

  function init() {
    const canvas = document.getElementById("city-canvas");
    if (canvas instanceof HTMLCanvasElement) {
      new CityCanvas(canvas);
    }

    initHeader();
    initReveal();
    initCounters();
    initLeaderboard();
    initFaq();
    initPointerLift();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}());
