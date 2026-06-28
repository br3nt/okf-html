require "cgi"
require "time"
require "nokogiri"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"

require "okf/html/version"

# OKF/HTML — notes are complete, self-describing HTML documents; the link graph
# between them is the knowledge graph. This namespace holds the pure-Ruby
# implementation of SPEC.md: the document serializer, the vocabulary, templates,
# and the ported association DSL. It performs no I/O and knows nothing about
# Rails or ActiveRecord — collaborators (a note, an owner) are duck-typed.
module OKF
  # The vocabulary profile every note declares in force (SPEC §2.2).
  PROFILE = "https://br3nt.github.io/okf/"

  # The canonical URL prefix a note's identity resolves under (SPEC §4).
  CANONICAL_PREFIX = "/n/"
end

require "okf/vocabulary"
require "okf/template_association"
require "okf/document"
require "okf/template"
require "okf/note"
require "okf/store"
require "okf/index"
require "okf/repository"
require "okf/filter"
require "okf/graph"
