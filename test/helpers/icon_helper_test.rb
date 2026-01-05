require "test_helper"

class IconHelperTest < ActionView::TestCase
  setup do
    IconHelper.clear_cache
    @icon = "icons/fontawesome/pen-solid.svg"
  end

  test "caches the SVG content" do
    first_result = cached_inline_svg(@icon)
    second_result = cached_inline_svg(@icon)
    assert_equal first_result, second_result
  end

  test "adds class attribute" do
    result = cached_inline_svg(@icon, class: "icon-class")
    assert_includes result, 'class="icon-class"'
  end

  test "adds data attributes" do
    result = cached_inline_svg(@icon, data: {test: "value"})
    assert_includes result, 'data-test="value"'
  end

  test "adds aria attributes" do
    result = cached_inline_svg(@icon, aria: {label: "Test Icon"})
    assert_includes result, 'aria-label="Test Icon"'
  end

  test "preserves existing viewBox attribute while adding new attributes" do
    result = cached_inline_svg(@icon, class: "icon-class")
    assert_includes result, 'viewBox="0 0 512 512"'
    assert_includes result, 'class="icon-class"'
    assert_not_includes result, 'hidden="true"'
  end

  test "handles multiple attributes" do
    result = cached_inline_svg(@icon,
      class: "icon-class",
      data: {test: "value"},
      aria: {label: "Test Icon"},
      role: "img")

    assert_includes result, 'class="icon-class"'
    assert_includes result, 'data-test="value"'
    assert_includes result, 'aria-label="Test Icon"'
    assert_includes result, 'role="img"'
  end

  test "escapes attribute values" do
    result = cached_inline_svg(@icon, data: {test: 'value"with"quotes'})
    assert_includes result, 'data-test="value&quot;with&quot;quotes"'
  end

  test "raises helpful error with fontawesome search URL when icon not found" do
    error = assert_raises(ArgumentError) do
      cached_inline_svg("icons/fontawesome/nonexistent-icon-solid.svg")
    end

    assert_includes error.message, "Icon not found. Download from\n"
    assert_includes error.message, "https://fontawesome.com/icons?q=nonexistent-icon"
    assert_includes error.message, "\nand save to\n"
    assert_includes error.message, "app/assets/images/icons/fontawesome/nonexistent-icon-solid.svg"
    assert_includes error.message, "Or run the following curl command:\ncurl -o"
    assert_includes error.message, "https://raw.githubusercontent.com/FortAwesome/Font-Awesome/7.x/svgs-full/solid/nonexistent-icon.svg"
  end
end
