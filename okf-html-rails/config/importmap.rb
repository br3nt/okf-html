# OKF/HTML editor — importmap pins for a no-build host (importmap + propshaft).
# A host draws these from the engine; see the engine README. The editor and the
# vendored Tiptap/ProseMirror ESM are served from the engine's asset paths.

pin "okf/editor", to: "okf/editor.js"

pin "@tiptap/core", to: "@tiptap--core.js" # @3.27.1
pin "@tiptap/starter-kit", to: "@tiptap--starter-kit.js" # @3.26.0
pin "@tiptap/core/jsx-runtime", to: "@tiptap--core--jsx-runtime.js" # @3.26.0
pin "@tiptap/core-chunk", to: "@tiptap--core-chunk.js"
pin "@tiptap/extension-blockquote", to: "@tiptap--extension-blockquote.js" # @3.26.0
pin "@tiptap/extension-bold", to: "@tiptap--extension-bold.js" # @3.26.0
pin "@tiptap/extension-code", to: "@tiptap--extension-code.js" # @3.26.0
pin "@tiptap/extension-code-block", to: "@tiptap--extension-code-block.js" # @3.26.0
pin "@tiptap/extension-document", to: "@tiptap--extension-document.js" # @3.26.0
pin "@tiptap/extension-hard-break", to: "@tiptap--extension-hard-break.js" # @3.26.0
pin "@tiptap/extension-heading", to: "@tiptap--extension-heading.js" # @3.26.0
pin "@tiptap/extension-horizontal-rule", to: "@tiptap--extension-horizontal-rule.js" # @3.26.0
pin "@tiptap/extension-italic", to: "@tiptap--extension-italic.js" # @3.26.0
pin "@tiptap/extension-link", to: "@tiptap--extension-link.js" # @3.26.0
pin "@tiptap/extension-list", to: "@tiptap--extension-list.js" # @3.27.1
pin "@tiptap/extension-paragraph", to: "@tiptap--extension-paragraph.js" # @3.26.0
pin "@tiptap/extension-strike", to: "@tiptap--extension-strike.js" # @3.26.0
pin "@tiptap/extension-text", to: "@tiptap--extension-text.js" # @3.26.0
pin "@tiptap/extension-underline", to: "@tiptap--extension-underline.js" # @3.26.0
pin "@tiptap/extensions", to: "@tiptap--extensions.js" # @3.26.0
pin "@tiptap/pm/commands", to: "@tiptap--pm--commands.js" # @3.27.1
pin "@tiptap/pm/dropcursor", to: "@tiptap--pm--dropcursor.js" # @3.26.0
pin "@tiptap/pm/gapcursor", to: "@tiptap--pm--gapcursor.js" # @3.26.0
pin "@tiptap/pm/history", to: "@tiptap--pm--history.js" # @3.26.0
pin "@tiptap/pm/keymap", to: "@tiptap--pm--keymap.js" # @3.27.1
pin "@tiptap/pm/model", to: "@tiptap--pm--model.js" # @3.27.1
pin "@tiptap/pm/schema-list", to: "@tiptap--pm--schema-list.js" # @3.27.1
pin "@tiptap/pm/state", to: "@tiptap--pm--state.js" # @3.27.1
pin "@tiptap/pm/transform", to: "@tiptap--pm--transform.js" # @3.27.1
pin "@tiptap/pm/view", to: "@tiptap--pm--view.js" # @3.27.1
pin "linkifyjs" # @4.3.3
pin "orderedmap" # @2.1.1
pin "prosemirror-commands" # @1.7.1
pin "prosemirror-dropcursor" # @1.8.2
pin "prosemirror-gapcursor" # @1.4.1
pin "prosemirror-history" # @1.5.0
pin "prosemirror-keymap" # @1.2.3
pin "prosemirror-model" # @1.25.9
pin "prosemirror-schema-list" # @1.5.1
pin "prosemirror-state" # @1.4.4
pin "prosemirror-transform" # @1.12.0
pin "prosemirror-view" # @1.41.9
pin "rope-sequence" # @1.3.4
pin "w3c-keyname" # @2.2.8
pin "@tiptap/extension-task-item", to: "@tiptap--extension-task-item.js" # @3.27.1
pin "@tiptap/extension-task-list", to: "@tiptap--extension-task-list.js" # @3.27.1
