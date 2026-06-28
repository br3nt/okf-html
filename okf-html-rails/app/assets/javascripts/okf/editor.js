// The OKF/HTML note editor, packaged as a no-build engine asset. A host mounts
// it per note and gets back { getHTML, destroy }:
//
//   import { mountEditor } from "okf/editor"
//   const handle = mountEditor(el, {
//     content,                 // initial HTML (else el.dataset.initialContent)
//     updateUrl,               // PATCH target for autosave (form params, HTML back)
//     wikilinksUrl,            // GET: an HTML list of notes for [[wikilink]] resolve
//     vocabularyUrl,           // GET: the vocabulary as HTML for the rel picker
//     csrfToken                // optional; falls back to <meta name="csrf-token">
//   })
//
// Everything travels as HTML, never JSON: lists are parsed from markup, and the
// autosave PATCHes a form body whose note[content] is the editor's HTML.

import { Editor, Extension, InputRule, markInputRule } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import TaskList from "@tiptap/extension-task-list"
import TaskItem from "@tiptap/extension-task-item"

const parseHtml = (html) => new DOMParser().parseFromString(html, "text/html")
const slugFromHref = (href) => (href || "").split("/n/")[1]
const slugify = (text) => text.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")

function defaultCsrfToken() {
  const meta = document.querySelector("meta[name=csrf-token]")
  return meta ? meta.getAttribute("content") : ""
}

export function mountEditor(mountEl, opts = {}) {
  const root = mountEl.querySelector(".note") || mountEl
  const contentEl = root.querySelector(".note-content") || mountEl
  const titleInput = root.querySelector(".note-title")
  const statusEl = root.querySelector(".note-status")
  const pinButton = root.querySelector(".note-pin")
  const deleteButton = root.querySelector(".note-delete")

  const uuid = mountEl.dataset.noteUuid || mountEl.getAttribute("uuid")
  const updateUrl = opts.updateUrl || (uuid ? `/n/${uuid}` : null)
  const wikilinksUrl = opts.wikilinksUrl || opts.notesUrl || "/n/catalog"
  const vocabularyUrl = opts.vocabularyUrl || "/vocabulary"
  const templatesUrl = opts.templatesUrl || null // enables the associations panel
  const csrf = () => opts.csrfToken || defaultCsrfToken()
  const saveDelay = opts.saveDelay || 800

  let saveTimer, linkPanelHideTimer

  // Send note[...] as a form body — HTML is the data contract, not JSON. Array
  // fields (metadata/links/associations) get a trailing empty `[]` sentinel so an
  // emptied list still clears server-side (Rails strong params drop the sentinel).
  const noteForm = (fields, lists = {}) => {
    const params = new URLSearchParams()
    for (const [key, value] of Object.entries(fields)) params.append(`note[${key}]`, value)
    for (const [key, items] of Object.entries(lists)) {
      items.forEach((item) => {
        for (const [field, value] of Object.entries(item)) {
          if (value !== undefined && value !== null) params.append(`note[${key}][][${field}]`, value)
        }
      })
      params.append(`note[${key}][]`, "")
    }
    return params
  }

  // [[Title]] resolves to /n/<slug> against a list fetched as HTML from wikilinksUrl.
  let notesIndex = []
  fetch(wikilinksUrl, { headers: { Accept: "text/html" } })
    .then((r) => (r.ok ? r.text() : ""))
    .then((html) => {
      notesIndex = Array.from(parseHtml(html).querySelectorAll("a")).map((a) => ({
        title: a.textContent.trim(),
        slug: slugFromHref(a.getAttribute("href"))
      }))
    })
    .catch(() => {})

  const resolveWikilink = (title) => {
    const hit = notesIndex.find((n) => n.title.toLowerCase() === title.toLowerCase())
    return hit ? `/n/${hit.slug}` : `/n/${slugify(title)}`
  }

  const Wikilink = Extension.create({
    name: "wikilink",
    addInputRules() {
      return [
        markInputRule({
          find: /(?:^|\s)(\[\[([^\[\]]+)\]\])$/,
          type: this.editor.schema.marks.link,
          getAttributes: (match) => ({ href: resolveWikilink(match[2]) })
        })
      ]
    }
  })

  // #tag becomes an in-content tag link — a tag IS a link.
  const Hashtag = Extension.create({
    name: "hashtag",
    addInputRules() {
      return [
        new InputRule({
          find: /(?:^|\s)(#([a-z0-9][a-z0-9_-]*))\s$/,
          handler: ({ range, match, chain }) => {
            const tagText = match[1]
            const start = range.from + match[0].indexOf(tagText)
            chain().insertContentAt({ from: start, to: range.to }, [
              { type: "text", text: tagText, marks: [ { type: "link", attrs: { href: `/tags/${match[2]}`, rel: "tag", class: "tag-chip" } } ] },
              { type: "text", text: " " }
            ]).run()
          }
        })
      ]
    }
  })

  const editor = new Editor({
    element: contentEl,
    extensions: [
      StarterKit.configure({ link: { HTMLAttributes: { target: null, rel: null } } }),
      TaskList,
      TaskItem.configure({ nested: true }),
      Wikilink,
      Hashtag,
      Extension.create({
        name: "linkShortcut",
        addKeyboardShortcuts() {
          return { "Mod-k": () => { openLinkEditor(); return true } }
        }
      })
    ],
    content: opts.content != null ? opts.content : (contentEl.dataset.initialContent || ""),
    onUpdate: () => scheduleSave()
  })

  // --- Toolbar ------------------------------------------------------------
  const toolbar = document.createElement("div")
  toolbar.className = "note-toolbar"
  const TOOLBAR_BUTTONS = [
    { label: "B", title: "Bold", run: (c) => c.toggleBold(), active: "bold" },
    { label: "I", title: "Italic", run: (c) => c.toggleItalic(), active: "italic" },
    { label: "S", title: "Strikethrough", run: (c) => c.toggleStrike(), active: "strike" },
    { label: "H1", title: "Heading 1", run: (c) => c.toggleHeading({ level: 1 }), active: "heading", level: 1 },
    { label: "H2", title: "Heading 2", run: (c) => c.toggleHeading({ level: 2 }), active: "heading", level: 2 },
    { label: "• List", title: "Bullet list", run: (c) => c.toggleBulletList(), active: "bulletList" },
    { label: "1. List", title: "Numbered list", run: (c) => c.toggleOrderedList(), active: "orderedList" },
    { label: "☑", title: "Task list", run: (c) => c.toggleTaskList(), active: "taskList" },
    { label: "Link", title: "Link (⌘K)", onClick: () => openLinkEditor() },
    { label: "Clear", title: "Clear formatting", run: (c) => c.unsetAllMarks().clearNodes() }
  ]
  const toolbarButtons = TOOLBAR_BUTTONS.map((spec) => {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "note-toolbar-button"
    button.textContent = spec.label
    button.title = spec.title
    if (spec.active) {
      button.dataset.active = spec.active
      if (spec.level) button.dataset.level = String(spec.level)
    }
    button.addEventListener("mousedown", (event) => event.preventDefault())
    button.addEventListener("click", () => {
      if (spec.onClick) { spec.onClick(); return }
      spec.run(editor.chain().focus()).run()
    })
    toolbar.appendChild(button)
    return { spec, button }
  })
  contentEl.insertBefore(toolbar, contentEl.firstChild)

  function updateToolbarState() {
    toolbarButtons.forEach(({ spec, button }) => {
      if (!spec.active) return
      const isActive = spec.level ? editor.isActive(spec.active, { level: spec.level }) : editor.isActive(spec.active)
      button.classList.toggle("is-active", isActive)
    })
  }
  editor.on("selectionUpdate", updateToolbarState)
  editor.on("transaction", updateToolbarState)
  updateToolbarState()

  // --- Link panel + rel picker -------------------------------------------
  const linkPanel = document.createElement("div")
  linkPanel.className = "link-panel"
  linkPanel.hidden = true
  linkPanel.innerHTML = `
    <input type="text" class="link-panel-href" placeholder="https:// or /n/note-slug">
    <input type="text" class="link-panel-rel" placeholder="relationship (e.g. chapter)" list="okf-rel-list" autocomplete="off">
    <a class="link-panel-open" title="Open link">↗</a>
    <button type="button" class="link-panel-remove" title="Remove link">✕</button>
    <span class="link-panel-warning" hidden></span>`
  root.appendChild(linkPanel)

  const relList = document.createElement("datalist")
  relList.id = "okf-rel-list"
  root.appendChild(relList)
  let discouragedRels = []
  let schemesData = []
  let headLinkRels = []

  // The vocabulary as HTML (terms carry their inverse in data-inverse, schemes
  // their metadata names in data-names) — read from the DOM, never JSON. The
  // promise lets the properties/associations panels wire up once it has loaded.
  const vocabReady = fetch(vocabularyUrl, { headers: { Accept: "text/html" } })
    .then((r) => (r.ok ? r.text() : null))
    .then((html) => {
      if (!html) return null
      const doc = parseHtml(html)
      discouragedRels = Array.from(doc.querySelectorAll(".vocab-discouraged li")).map((li) => li.textContent.trim())
      schemesData = Array.from(doc.querySelectorAll(".vocab-schemes li")).map((li) => ({
        scheme: li.dataset.scheme,
        names: (li.dataset.names || "").split(/\s+/).filter(Boolean)
      }))
      headLinkRels = Array.from(doc.querySelectorAll(".vocab-head-link-rels li")).map((li) => li.textContent.trim())
      relList.innerHTML = Array.from(doc.querySelectorAll(".vocab-terms li"))
        .map((li) => `<option value="${li.dataset.rel}">${li.dataset.inverse ? "↔ " + li.dataset.inverse : ""}</option>`)
        .join("")
      return true
    })
    .catch(() => null)

  const linkPanelInput = linkPanel.querySelector(".link-panel-href")
  const linkPanelRel = linkPanel.querySelector(".link-panel-rel")
  const linkPanelWarning = linkPanel.querySelector(".link-panel-warning")
  const linkPanelOpen = linkPanel.querySelector(".link-panel-open")
  let panelLinkElement = null
  let cmdkRange = null

  function updateRelWarning() {
    const rel = linkPanelRel.value.trim().toLowerCase()
    const vague = rel && discouragedRels.includes(rel)
    linkPanelWarning.hidden = !vague
    if (vague) linkPanelWarning.textContent = `“${rel}” is positional and vague — prefer a named relationship`
  }
  linkPanelRel.addEventListener("input", updateRelWarning)
  linkPanelRel.addEventListener("keydown", (event) => {
    if (event.key === "Enter") { event.preventDefault(); applyLink() }
    if (event.key === "Escape") hideLinkPanel()
  })
  linkPanel.addEventListener("mouseenter", () => clearTimeout(linkPanelHideTimer))
  linkPanel.addEventListener("mouseleave", () => scheduleLinkPanelHide())
  linkPanelInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") { event.preventDefault(); applyLink() }
    if (event.key === "Escape") hideLinkPanel()
  })
  linkPanel.querySelector(".link-panel-remove").addEventListener("click", () => {
    selectPanelLink()
    editor.chain().focus().extendMarkRange("link").unsetLink().run()
    hideLinkPanel()
  })

  function showLinkPanelFor(linkElement) {
    clearTimeout(linkPanelHideTimer)
    panelLinkElement = linkElement
    linkPanelInput.value = linkElement.getAttribute("href") || ""
    linkPanelRel.value = linkElement.getAttribute("rel") || ""
    linkPanelOpen.href = linkPanelInput.value
    updateRelWarning()
    positionLinkPanel(linkElement.getBoundingClientRect())
  }
  function openLinkEditor() {
    panelLinkElement = null
    const { from, to } = editor.state.selection
    cmdkRange = { from, to }
    linkPanelInput.value = editor.getAttributes("link").href || ""
    linkPanelRel.value = editor.getAttributes("link").rel || ""
    linkPanelOpen.href = linkPanelInput.value
    updateRelWarning()
    const coords = editor.view.coordsAtPos(from)
    positionLinkPanel({ left: coords.left, bottom: coords.bottom })
    linkPanelInput.focus()
  }
  function positionLinkPanel(rect) {
    const host = root.getBoundingClientRect()
    linkPanel.style.left = `${Math.max(8, rect.left - host.left)}px`
    linkPanel.style.top = `${rect.bottom - host.top + 6}px`
    linkPanel.hidden = false
  }
  function selectPanelLink() {
    if (!panelLinkElement) return
    const pos = editor.view.posAtDOM(panelLinkElement, 0)
    editor.chain().setTextSelection(pos + 1).run()
  }
  function applyLink() {
    const href = linkPanelInput.value.trim()
    const rel = linkPanelRel.value.trim()
    const attrs = rel ? { href, rel } : { href }
    if (panelLinkElement) selectPanelLink()
    else if (cmdkRange) editor.chain().setTextSelection(cmdkRange).run()
    const { from, to } = editor.state.selection
    if (href === "") {
      editor.chain().focus().extendMarkRange("link").unsetLink().run()
    } else if (from === to && !editor.isActive("link")) {
      editor.chain().focus().insertContentAt(from, [ { type: "text", text: href, marks: [ { type: "link", attrs } ] } ]).run()
    } else {
      editor.chain().focus().extendMarkRange("link").setLink(attrs).run()
    }
    hideLinkPanel()
  }
  function scheduleLinkPanelHide() {
    clearTimeout(linkPanelHideTimer)
    linkPanelHideTimer = setTimeout(() => hideLinkPanel(), 400)
  }
  function hideLinkPanel() {
    linkPanel.hidden = true
    panelLinkElement = null
    cmdkRange = null
  }
  const onContentMouseOver = (event) => {
    const link = event.target.closest("a")
    if (link && contentEl.contains(link)) showLinkPanelFor(link)
  }
  const onContentMouseOut = (event) => { if (event.target.closest("a")) scheduleLinkPanelHide() }
  contentEl.addEventListener("mouseover", onContentMouseOver)
  contentEl.addEventListener("mouseout", onContentMouseOut)

  // --- Autosave -----------------------------------------------------------
  function showStatus(message, kind = "info") {
    if (!statusEl) return
    statusEl.textContent = message
    statusEl.dataset.kind = kind
  }
  function scheduleSave() {
    if (!updateUrl) return
    showStatus("…")
    clearTimeout(saveTimer)
    saveTimer = setTimeout(save, saveDelay)
  }
  async function save() {
    if (!updateUrl) return
    try {
      const fields = { content: editor.getHTML() }
      if (titleInput) fields.title = titleInput.value
      const response = await fetch(updateUrl, {
        method: "PATCH",
        headers: { Accept: "text/html", "X-CSRF-Token": csrf() },
        body: noteForm(fields)
      })
      if (!response.ok) throw new Error(`Save failed (${response.status})`)
      const saved = parseHtml(await response.text()).querySelector("[data-slug]")
      showStatus("Saved")
      if (saved) mountEl.dataset.slug = saved.dataset.slug
    } catch (error) {
      console.error("OKF autosave error:", error)
      showStatus("Save failed — retrying…", "error")
      clearTimeout(saveTimer)
      saveTimer = setTimeout(save, 3000)
    }
  }
  const onTitleInput = () => scheduleSave()
  titleInput?.addEventListener("input", onTitleInput)

  // --- Optional pin / delete chrome (wired only if the host renders them) --
  const onPin = async () => {
    if (!updateUrl) return
    const pinned = pinButton.dataset.pinned !== "true"
    const response = await fetch(updateUrl, {
      method: "PATCH",
      headers: { Accept: "text/html", "X-CSRF-Token": csrf() },
      body: noteForm({ pinned })
    })
    if (response.ok) {
      pinButton.dataset.pinned = String(pinned)
      pinButton.textContent = pinned ? "★" : "☆"
    }
  }
  pinButton?.addEventListener("click", onPin)

  const onDelete = async () => {
    if (!updateUrl || !confirm("Delete this note?")) return
    const response = await fetch(updateUrl, { method: "DELETE", headers: { Accept: "text/html", "X-CSRF-Token": csrf() } })
    if (response.ok) mountEl.remove()
  }
  deleteButton?.addEventListener("click", onDelete)

  // --- Optional properties panel (custom <meta> + head <link>, §3/§4) ------
  // Wired only if the host renders a `.note-properties` block. A Meta row authors
  // a <meta scheme name value>, a Link row a head <link rel href>; on save the
  // rows are split by kind and PATCHed together as form arrays.
  const properties = updateUrl && root.querySelector(".note-properties")
  if (properties) {
    const rowsEl = properties.querySelector(".properties-rows")
    const propStatus = properties.querySelector(".prop-status")
    let nameListSeq = 0

    const schemeList = document.createElement("datalist")
    schemeList.id = `prop-scheme-list-${uuid}`
    const headRelList = document.createElement("datalist")
    headRelList.id = `prop-head-rel-list-${uuid}`
    root.append(schemeList, headRelList)

    const optionsHtml = (values) => values.map((value) => `<option value="${value}">`).join("")
    const allNames = () => [ ...new Set(schemesData.flatMap((scheme) => scheme.names || [])) ]

    const refreshNameList = (row) => {
      const list = row.querySelector(".prop-name-list")
      if (!list) return
      const chosen = row.querySelector(".prop-scheme").value.trim()
      const match = schemesData.find((scheme) => scheme.scheme === chosen)
      list.innerHTML = optionsHtml(match ? (match.names || []) : allNames())
    }

    const refreshRowWarning = (row) => {
      const warning = row.querySelector(".prop-warning")
      const rel = row.querySelector(".prop-rel").value.trim().toLowerCase()
      const vague = rel && discouragedRels.includes(rel)
      warning.hidden = !vague
      if (vague) warning.textContent = `“${rel}” is positional and vague — prefer a named relationship`
    }

    const enhanceRow = (row) => {
      const kind = row.querySelector(".prop-kind")
      const schemeInput = row.querySelector(".prop-scheme")
      const nameInput = row.querySelector(".prop-name")
      const relInput = row.querySelector(".prop-rel")

      schemeInput.setAttribute("list", schemeList.id)
      relInput.setAttribute("list", headRelList.id)

      const nameList = document.createElement("datalist")
      nameList.id = `prop-name-list-${uuid}-${nameListSeq++}`
      nameList.className = "prop-name-list"
      nameInput.setAttribute("list", nameList.id)
      row.appendChild(nameList)

      kind.addEventListener("change", () => { row.dataset.kind = kind.value })
      schemeInput.addEventListener("input", () => refreshNameList(row))
      relInput.addEventListener("input", () => refreshRowWarning(row))
      refreshNameList(row)
      refreshRowWarning(row)
    }

    const newRow = (kind = "meta") => {
      const row = document.createElement("div")
      row.className = "property-row"
      row.dataset.kind = kind
      row.innerHTML = `
        <select class="prop-kind" title="Row kind">
          <option value="meta"${kind === "meta" ? " selected" : ""}>Meta</option>
          <option value="link"${kind === "link" ? " selected" : ""}>Link</option>
        </select>
        <span class="prop-fields prop-meta-fields">
          <input class="prop-scheme" placeholder="scheme" autocomplete="off">
          <input class="prop-name" placeholder="name" autocomplete="off">
          <input class="prop-value" placeholder="value">
        </span>
        <span class="prop-fields prop-link-fields">
          <input class="prop-rel" placeholder="rel" autocomplete="off">
          <input class="prop-href" placeholder="/n/note-slug or https://">
          <span class="prop-warning" hidden></span>
        </span>
        <button type="button" class="prop-remove" title="Remove row">✕</button>`
      return row
    }

    vocabReady.then(() => {
      schemeList.innerHTML = optionsHtml(schemesData.map((scheme) => scheme.scheme))
      headRelList.innerHTML = optionsHtml(headLinkRels)
      rowsEl.querySelectorAll(".property-row").forEach(enhanceRow)
    })

    properties.querySelector(".prop-add").addEventListener("click", () => {
      const row = newRow()
      rowsEl.appendChild(row)
      enhanceRow(row)
    })
    rowsEl.addEventListener("click", (event) => {
      if (event.target.classList.contains("prop-remove")) event.target.closest(".property-row").remove()
    })
    properties.querySelector(".prop-save").addEventListener("click", async () => {
      const metadata = []
      const links = []
      rowsEl.querySelectorAll(".property-row").forEach((row) => {
        if (row.dataset.kind === "link") {
          const rel = row.querySelector(".prop-rel").value.trim()
          const href = row.querySelector(".prop-href").value.trim()
          if (rel || href) links.push({ rel, href })
        } else {
          const name = row.querySelector(".prop-name").value.trim()
          if (name) metadata.push({ name, value: row.querySelector(".prop-value").value.trim(), scheme: row.querySelector(".prop-scheme").value.trim() })
        }
      })
      propStatus.textContent = "…"
      try {
        const response = await fetch(updateUrl, {
          method: "PATCH",
          headers: { Accept: "text/html", "X-CSRF-Token": csrf() },
          body: noteForm({}, { metadata, links })
        })
        propStatus.textContent = response.ok ? "Saved" : "Save failed"
      } catch {
        propStatus.textContent = "Save failed"
      }
    })
  }

  // --- Optional template-associations panel (§9.2) ------------------------
  // Wired only if the host renders a `.note-associations` block and supplies a
  // templatesUrl (an HTML list of templates with data-uuid). Declares has-many /
  // has-one / belongs-to relationships to other templates.
  const associations = updateUrl && templatesUrl && root.querySelector(".note-associations")
  if (associations) {
    const assocRowsEl = associations.querySelector(".associations-rows")
    const assocStatus = associations.querySelector(".assoc-status")
    let templatesIndex = []

    const targetOptions = (selected) =>
      `<option value="">— template —</option>` +
      templatesIndex
        .filter((tmpl) => tmpl.uuid !== uuid)
        .map((tmpl) => `<option value="${tmpl.uuid}"${tmpl.uuid === selected ? " selected" : ""}>${tmpl.title}</option>`)
        .join("")

    const fillTargets = () => {
      assocRowsEl.querySelectorAll(".association-row").forEach((row) => {
        row.querySelector(".assoc-target").innerHTML = targetOptions(row.dataset.templateUuid || "")
      })
    }
    fetch(templatesUrl, { headers: { Accept: "text/html" } })
      .then((response) => (response.ok ? response.text() : ""))
      .then((html) => {
        templatesIndex = Array.from(parseHtml(html).querySelectorAll("li a")).map((a) => ({ uuid: a.dataset.uuid, title: a.textContent.trim() }))
        fillTargets()
      })
      .catch(() => {})

    const newAssocRow = () => {
      const row = document.createElement("div")
      row.className = "association-row"
      row.innerHTML = `
        <select class="assoc-kind" title="Association kind">
          <option value="has-many">has-many</option>
          <option value="has-one">has-one</option>
          <option value="belongs-to">belongs-to</option>
        </select>
        <input class="assoc-as" placeholder="as (e.g. chapter)" autocomplete="off">
        <select class="assoc-target" title="Target template">${targetOptions("")}</select>
        <button type="button" class="assoc-remove" title="Remove association">✕</button>`
      return row
    }

    associations.querySelector(".assoc-add").addEventListener("click", () => assocRowsEl.appendChild(newAssocRow()))
    assocRowsEl.addEventListener("click", (event) => {
      if (event.target.classList.contains("assoc-remove")) event.target.closest(".association-row").remove()
    })
    associations.querySelector(".assoc-save").addEventListener("click", async () => {
      const payload = Array.from(assocRowsEl.querySelectorAll(".association-row")).map((row) => {
        const kind = row.querySelector(".assoc-kind").value
        return {
          kind,
          as: row.querySelector(".assoc-as").value.trim(),
          template_uuid: row.querySelector(".assoc-target").value,
          // Only send ordered when true: the server coerces with !!, so "false" would read truthy.
          ordered: kind === "has-many" ? "true" : undefined
        }
      }).filter((assoc) => assoc.as && assoc.template_uuid)
      assocStatus.textContent = "…"
      try {
        const response = await fetch(updateUrl, {
          method: "PATCH",
          headers: { Accept: "text/html", "X-CSRF-Token": csrf() },
          body: noteForm({}, { associations: payload })
        })
        assocStatus.textContent = response.ok ? "Saved" : "Save failed"
      } catch {
        assocStatus.textContent = "Save failed"
      }
    })
  }

  if (mountEl.hasAttribute("autofocus")) titleInput?.focus()

  // --- Handle -------------------------------------------------------------
  function destroy() {
    clearTimeout(saveTimer)
    clearTimeout(linkPanelHideTimer)
    contentEl.removeEventListener("mouseover", onContentMouseOver)
    contentEl.removeEventListener("mouseout", onContentMouseOut)
    titleInput?.removeEventListener("input", onTitleInput)
    editor.destroy()
    toolbar.remove()
    linkPanel.remove()
    relList.remove()
  }

  return { getHTML: () => editor.getHTML(), editor, destroy }
}

// Expose on window.OKF for hosts that mount via a custom element or inline script.
window.OKF = window.OKF || {}
window.OKF.mountEditor = mountEditor
