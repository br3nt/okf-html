require "test_helper"

# SPEC §9.1 — a template's prototype is instantiated by filling slots/fields and
# stripping the authoring scaffolding, leaving the semantic markup behind.
class OKF::TemplateTest < Minitest::Test
  def test_build_fills_slots_and_strips_scaffolding
    note = FakeNote.new(content: %(<template>) +
      %(<article class="h-card"><h1 class="p-name"><slot name="name"></slot></h1>) +
      %(<p data-field="role" data-placeholder="Role"></p></article></template>))

    html = OKF::Template.new(note).build("name" => "Jane Doe", "role" => "Engineer")

    assert_includes html, "Jane Doe"
    assert_includes html, "Engineer"
    assert_includes html, "h-card"
    refute_includes html, "<slot"
    refute_includes html, "data-placeholder"
    refute_includes html, "data-field"
  end

  def test_unfilled_slots_disappear
    note = FakeNote.new(content: %(<template><p><slot name="x"></slot></p></template>))
    html = OKF::Template.new(note).build

    refute_includes html, "<slot"
  end
end
