require "test_helper"

# SPEC §2/§3/§4 — a note renders to a complete, self-describing HTML document and
# parses back into the same attributes (files are truth, §1).
class OKF::DocumentTest < Minitest::Test
  def test_render_emits_a_complete_document_with_identity_in_the_head
    note = FakeNote.new(uuid: "abc", slug: "my-note", effective_title: "My Note",
      tag_names: %w[ruby notes], content: "<p>body</p>")
    html = OKF::Document.render(note)

    assert_includes html, "<!DOCTYPE html>"
    assert_includes html, %(<head profile="#{OKF::PROFILE}">)
    assert_includes html, "<title>My Note</title>"
    assert_includes html, %(<link rel="canonical" href="/n/my-note">)
    assert_includes html, %(<meta name="uuid" scheme="UUID" content="abc">)
    assert_includes html, %(<meta name="keywords" content="ruby, notes">)
    assert_includes html, "<body>\n<p>body</p>\n</body>"
  end

  def test_custom_metadata_and_links_round_trip
    note = FakeNote.new(slug: "linky",
      metadata: [ { "name" => "author", "value" => "Jane", "scheme" => "DC" } ],
      links: [ { "rel" => "license", "href" => "/n/cc-by" } ])
    parsed = OKF::Document.parse(OKF::Document.render(note))

    assert_equal "Jane", parsed.metadata.first["value"]
    assert_equal "DC", parsed.metadata.first["scheme"]
    assert_equal "license", parsed.links.first["rel"]
    assert_equal "/n/cc-by", parsed.links.first["href"]
    assert_equal "linky", parsed.slug
  end

  def test_pinned_and_template_flags_round_trip
    note = FakeNote.new(pinned: true, template: true)
    parsed = OKF::Document.parse(OKF::Document.render(note))

    assert parsed.pinned?
    assert parsed.template?
  end
end
