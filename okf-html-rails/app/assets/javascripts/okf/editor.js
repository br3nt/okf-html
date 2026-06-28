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
  const csrf = () => opts.csrfToken || defaultCsrfToken()
  const saveDelay = opts.saveDelay || 800

  let saveTimer, linkPanelHideTimer

  // Send note[...] as a form body — HTML is the data contract, not JSON.
  const noteForm = (fields) => {
    const params = new URLSearchParams()
    for (const [key, value] of Object.entries(fields)) params.append(`note[${key}]`, value)
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

  // The vocabulary as HTML (terms carry their inverse in data-inverse, the
  // discouraged positional words are listed) — read from the DOM, never JSON.
  fetch(vocabularyUrl, { headers: { Accept: "text/html" } })
    .then((r) => (r.ok ? r.text() : null))
    .then((html) => {
      if (!html) return
      const doc = parseHtml(html)
      discouragedRels = Array.from(doc.querySelectorAll(".vocab-discouraged li")).map((li) => li.textContent.trim())
      relList.innerHTML = Array.from(doc.querySelectorAll(".vocab-terms li"))
        .map((li) => `<option value="${li.dataset.rel}">${li.dataset.inverse ? "↔ " + li.dataset.inverse : ""}</option>`)
        .join("")
    })
    .catch(() => {})

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
