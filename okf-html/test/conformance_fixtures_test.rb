require "test_helper"
require "yaml"

# The language-neutral conformance vectors in fixtures/*.yml (repo root) are
# hand-written from SPEC.md and executed against this reference implementation
# (see fixtures/README.md). This test makes them binding: every case here is
# run through the real OKF::Document API, so a fixture that regresses fails the
# suite, and a new fixture case adds coverage for free.
class OKF::ConformanceFixturesTest < Minitest::Test
  FIXTURES_DIR = File.expand_path("../../fixtures", __dir__)

  render_cases = YAML.load_file(File.join(FIXTURES_DIR, "render.yml"))["cases"]
  render_cases.each do |c|
    define_method("test_render_#{c["name"]}") do
      note = FixtureNote.new(c["input"])
      assert_equal c["expected_html"], OKF::Document.render(note)
    end
  end

  parse_cases = YAML.load_file(File.join(FIXTURES_DIR, "parse.yml"))["cases"]
  parse_cases.each do |c|
    define_method("test_parse_#{c["name"]}") do
      parsed = OKF::Document.parse(c["html"])
      expected = c["expected"]["document"]

      assert_fixture_equal expected["uuid"], parsed.uuid
      assert_fixture_equal expected["slug"], parsed.slug
      assert_fixture_equal expected["title"], parsed.title
      assert_fixture_equal expected["body"], parsed.body
      assert_fixture_equal expected["tag_names"], parsed.tag_names
      assert_fixture_equal expected["pinned"], parsed.pinned?
      assert_fixture_equal expected["template"], parsed.template?
      assert_fixture_equal expected["template_uuid"], parsed.template_uuid
      assert_fixture_equal expected["created_at"], parsed.created_at&.iso8601
      assert_fixture_equal expected["updated_at"], parsed.updated_at&.iso8601
      assert_fixture_equal expected["metadata"], parsed.metadata
      assert_fixture_equal expected["links"], parsed.links
      assert_fixture_equal expected["associations"], parsed.associations
    end

    define_method("test_index_#{c["name"]}") do
      entry = OKF::Index.entry_for(c["html"])
      expected = c["expected"]["index"]

      assert_equal expected["effective_title"], entry.effective_title
      outgoing = entry.outgoing.map { |h| { "rel" => h[:rel], "href" => h[:href] } }
      assert_equal expected["outgoing_links"], outgoing
      assert_equal expected["member_hrefs"], entry.member_hrefs
    end
  end

  # Minitest's assert_equal refuses a nil expected value (it wants assert_nil),
  # but fixture cases legitimately expect nil (e.g. an unset template_uuid) — so
  # dispatch to whichever assertion the expected value calls for.
  def assert_fixture_equal(expected, actual)
    expected.nil? ? assert_nil(actual) : assert_equal(expected, actual)
  end

  # A duck-typed note built straight from a render.yml fixture's `input` hash,
  # matching the interface OKF::Document.render expects (see test_helper's
  # FakeNote). Kept separate so string-keyed fixture data doesn't have to be
  # symbolized to fit FakeNote's keyword-based constructor, and so timestamp
  # strings are parsed into Time the way a real host attribute would be.
  class FixtureNote
    ATTRS = %w[uuid slug effective_title tag_names pinned template content
               metadata links associations template_uuid].freeze

    def initialize(input)
      @input = input
    end

    ATTRS.each do |name|
      define_method(name) { @input[name] }
    end

    def created_at = parse_time(@input["created_at"])
    def updated_at = parse_time(@input["updated_at"])
    def pinned?   = !!@input["pinned"]
    def template? = !!@input["template"]

    def incoming_links
      Array(@input["rev_links"]).map { |h| OKF::Backlink.new(h["rel"], h["source_slug"]) }
    end

    private

    def parse_time(value)
      value.present? ? Time.parse(value) : nil
    end
  end
end
