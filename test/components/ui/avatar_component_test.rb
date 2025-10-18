# frozen_string_literal: true

require "test_helper"

class Ui::AvatarComponentTest < ViewComponent::TestCase
  setup do
    @speaker = users(:one)
  end

  def test_render_image_when_there_is_a_custom_avatar
    @speaker.update!(github_handle: "testtest")
    render_inline(Ui::AvatarComponent.new(@speaker))

    assert_selector("img")
  end

  def test_render_initials_when_there_is_no_custom_avatar
    @speaker.update!(github_handle: "", name: "Max Mustermann")
    render_inline(Ui::AvatarComponent.new(@speaker))

    refute_selector("img")
    assert_text("MM")
  end

  def test_renders_by_default_md
    @speaker.update!(github_handle: "testtest")
    render_inline(Ui::AvatarComponent.new(@speaker))

    assert_selector(".w-12")
  end

  def test_renders_non_default_sizes
    @speaker.update!(github_handle: "testtest")
    render_inline(Ui::AvatarComponent.new(@speaker, size: :lg))

    assert_selector(".w-40")
  end
end
