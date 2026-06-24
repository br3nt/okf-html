$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "okf/html"
require "minitest/autorun"

# A duck-typed stand-in for a host's note: the attributes OKF::Document and the
# templates read, with sensible defaults. No ActiveRecord, no persistence.
class FakeNote
  ATTRS = %i[uuid slug effective_title created_at updated_at tag_names pinned
             template content metadata links associations template_uuid incoming_links].freeze

  def initialize(**attrs)
    @attrs = {
      uuid: "u-1", slug: "a-note", effective_title: "A note",
      created_at: nil, updated_at: nil, tag_names: [], pinned: false,
      template: false, content: "", metadata: [], links: [],
      associations: [], template_uuid: nil, incoming_links: []
    }.merge(attrs)
  end

  ATTRS.each { |name| define_method(name) { @attrs[name] } }
  def pinned?   = !!@attrs[:pinned]
  def template? = !!@attrs[:template]
end
