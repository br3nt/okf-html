require "test_helper"

# SPEC §6 — the vocabulary names which rels exist, their inverses (§7), and the
# discouraged positional words the naming rule warns against (§6.1).
class OKF::VocabularyTest < Minitest::Test
  def test_known_terms_report_their_inverse
    assert_equal "contents", OKF::Vocabulary.inverse("chapter")
    assert_equal "related", OKF::Vocabulary.inverse("related")
    assert_nil OKF::Vocabulary.inverse("author")
  end

  def test_positional_words_are_discouraged_not_unknown
    assert OKF::Vocabulary.discouraged?("up")
    assert OKF::Vocabulary.discouraged?("NEXT") # case-insensitive
    refute OKF::Vocabulary.discouraged?("chapter")
  end

  def test_schemes_and_head_link_rels_are_published
    assert_includes OKF::Vocabulary.schemes.map { |s| s[:scheme] }, "DC"
    assert_includes OKF::Vocabulary.head_link_rels, "icon"
    assert_includes OKF::Vocabulary.head_link_rels, "chapter"
  end
end
