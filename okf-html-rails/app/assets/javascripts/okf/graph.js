// The OKF/HTML graph visualiser, packaged as a no-build engine asset (no
// dependencies — a small vanilla force-directed SVG layout). The link graph is
// the knowledge graph, so the data is just notes + their /n/ links, fetched as
// HTML (the data contract) and read from the DOM.
//
//   import { mountGraph } from "okf/graph"
//   mountGraph(el, { graphUrl: "/graph", filter: "tag:plan" })
//
// graphUrl receives the filter as `?filter=<query>` and must return the subgraph
// HTML that OKF::Graph#to_html produces (.graph-node / .graph-edge lists).

const SVG_NS = "http://www.w3.org/2000/svg"
const parseHtml = (html) => new DOMParser().parseFromString(html, "text/html")

export function mountGraph(mountEl, opts = {}) {
  const graphUrl = opts.graphUrl || "/graph"
  const width = opts.width || mountEl.clientWidth || 720
  const height = opts.height || 480
  let filter = opts.filter || ""

  mountEl.classList.add("okf-graph-view")
  mountEl.innerHTML = `
    <form class="okf-graph-filter">
      <span class="okf-graph-chips"></span>
      <input class="okf-graph-input" type="text" placeholder="filter — e.g. tag:plan -tag:done rel:chapter updated:last:7d">
    </form>
    <div class="okf-graph-status"></div>
    <svg class="okf-graph-canvas" width="${width}" height="${height}"></svg>`

  const form = mountEl.querySelector(".okf-graph-filter")
  const input = mountEl.querySelector(".okf-graph-input")
  const chipsEl = mountEl.querySelector(".okf-graph-chips")
  const statusEl = mountEl.querySelector(".okf-graph-status")
  const svg = mountEl.querySelector(".okf-graph-canvas")
  let anim = null

  const renderChips = () => {
    const tokens = filter.split(/\s+/).filter(Boolean)
    chipsEl.innerHTML = tokens
      .map((t, i) => `<span class="okf-graph-chip" data-i="${i}">${escapeHtml(t)}<button type="button" aria-label="remove">×</button></span>`)
      .join("")
  }
  chipsEl.addEventListener("click", (e) => {
    const chip = e.target.closest(".okf-graph-chip")
    if (!chip || e.target.tagName !== "BUTTON") return
    const tokens = filter.split(/\s+/).filter(Boolean)
    tokens.splice(Number(chip.dataset.i), 1)
    filter = tokens.join(" ")
    renderChips(); load()
  })
  form.addEventListener("submit", (e) => {
    e.preventDefault()
    filter = `${filter} ${input.value}`.trim()
    input.value = ""
    renderChips(); load()
  })

  async function load() {
    statusEl.textContent = "Loading…"
    if (opts.onFilterChange) opts.onFilterChange(filter)
    try {
      const url = graphUrl + (graphUrl.includes("?") ? "&" : "?") + "filter=" + encodeURIComponent(filter)
      const res = await fetch(url, { headers: { Accept: "text/html" } })
      const doc = parseHtml(await res.text())
      const nodes = Array.from(doc.querySelectorAll(".graph-node")).map((li) => ({
        id: li.dataset.uuid,
        title: (li.textContent || "").trim(),
        tags: (li.dataset.tags || "").split(/\s+/).filter(Boolean),
        pinned: li.dataset.pinned === "true"
      }))
      const edges = Array.from(doc.querySelectorAll(".graph-edge")).map((li) => ({
        source: li.dataset.source, target: li.dataset.target, rel: li.dataset.rel
      }))
      statusEl.textContent = `${nodes.length} notes · ${edges.length} links`
      simulate(nodes, edges)
    } catch (err) {
      statusEl.textContent = "Failed to load graph"
      console.error("OKF graph:", err)
    }
  }

  // --- Force-directed layout (vanilla) ------------------------------------
  function simulate(nodes, edges) {
    if (anim) cancelAnimationFrame(anim)
    const byId = new Map(nodes.map((n) => [ n.id, n ]))
    const links = edges.filter((e) => byId.has(e.source) && byId.has(e.target))
    const cx = width / 2, cy = height / 2
    nodes.forEach((n, i) => {
      const a = (i / Math.max(1, nodes.length)) * Math.PI * 2
      n.x = cx + Math.cos(a) * 120 + (i % 3) * 7
      n.y = cy + Math.sin(a) * 120 + (i % 5) * 5
      n.vx = 0; n.vy = 0
    })

    let tick = 0
    const step = () => {
      // repulsion (every pair)
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const a = nodes[i], b = nodes[j]
          let dx = a.x - b.x, dy = a.y - b.y
          let d2 = dx * dx + dy * dy || 0.01
          const f = 2200 / d2
          const d = Math.sqrt(d2)
          const fx = (dx / d) * f, fy = (dy / d) * f
          a.vx += fx; a.vy += fy; b.vx -= fx; b.vy -= fy
        }
      }
      // springs along links
      links.forEach((l) => {
        const a = byId.get(l.source), b = byId.get(l.target)
        const dx = b.x - a.x, dy = b.y - a.y
        const d = Math.sqrt(dx * dx + dy * dy) || 0.01
        const f = (d - 90) * 0.02
        const fx = (dx / d) * f, fy = (dy / d) * f
        a.vx += fx; a.vy += fy; b.vx -= fx; b.vy -= fy
      })
      // gravity to center + integrate with damping
      nodes.forEach((n) => {
        n.vx += (cx - n.x) * 0.003
        n.vy += (cy - n.y) * 0.003
        n.vx *= 0.85; n.vy *= 0.85
        n.x += Math.max(-12, Math.min(12, n.vx))
        n.y += Math.max(-12, Math.min(12, n.vy))
        n.x = Math.max(20, Math.min(width - 20, n.x))
        n.y = Math.max(20, Math.min(height - 20, n.y))
      })
      render(nodes, links)
      if (++tick < 240) anim = requestAnimationFrame(step)
    }
    step()
  }

  function render(nodes, links) {
    const byId = new Map(nodes.map((n) => [ n.id, n ]))
    let out = ""
    links.forEach((l) => {
      const a = byId.get(l.source), b = byId.get(l.target)
      const mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2
      out += `<line class="okf-graph-link" x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}"></line>`
      if (l.rel) out += `<text class="okf-graph-rel" x="${mx}" y="${my}">${escapeHtml(l.rel)}</text>`
    })
    nodes.forEach((n) => {
      out += `<g class="okf-graph-node${n.pinned ? " is-pinned" : ""}" data-uuid="${escapeHtml(n.id)}" transform="translate(${n.x},${n.y})">` +
        `<circle r="7"></circle><text x="11" y="4">${escapeHtml(n.title)}</text></g>`
    })
    svg.innerHTML = out
  }

  svg.addEventListener("click", (e) => {
    const g = e.target.closest(".okf-graph-node")
    if (!g) return
    const uuid = g.dataset.uuid
    if (opts.onSelect) opts.onSelect(uuid)
    else window.location.href = `/n/${uuid}`
  })

  renderChips()
  load()
  return { reload: load, setFilter: (f) => { filter = f; renderChips(); load() } }
}

function escapeHtml(s) {
  return String(s == null ? "" : s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]))
}

window.OKF = window.OKF || {}
window.OKF.mountGraph = mountGraph
