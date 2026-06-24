require "test_helper"

# SPEC §9.2 — a template's association declarations round-trip between the
# document head <link>, the json column, and the in-memory object.
class OKF::TemplateAssociationTest < Minitest::Test
  def test_from_link_reads_a_declared_association
    link = Nokogiri::HTML5.fragment(
      %(<link rel="okf:has-many" href="/templates/chapter" data-as="chapter" data-ordered="true">)
    ).at_css("link")
    assoc = OKF::TemplateAssociation.from_link(link)

    assert_equal "has-many", assoc.kind
    assert_equal "chapter", assoc.as
    assert assoc.ordered?
    assert assoc.collection?
  end

  def test_uuid_target_resolves_to_a_canonical_href
    assoc = OKF::TemplateAssociation.from_hash(
      "kind" => "has-one", "as" => "author", "template_uuid" => "xyz"
    )
    assert_equal "/n/xyz", assoc.template_href
  end

  def test_round_trips_through_hash_and_link
    assoc = OKF::TemplateAssociation.from_hash(
      "kind" => "has-many", "as" => "chapter", "template_href" => "/templates/chapter", "ordered" => true
    )
    again = OKF::TemplateAssociation.from_hash(assoc.to_h)

    assert_equal "chapter", again.as
    assert again.ordered?
    assert_includes assoc.to_link, %(rel="okf:has-many")
    assert_includes assoc.to_link, %(data-ordered="true")
  end
end
