# frozen_string_literal: true

require "test_helper"

class Ui::StampComponentTest < ViewComponent::TestCase
  setup do
    @country_stamp = Stamp.for_country("BE")

    @contributor_stamp = Stamp.contributor_stamp
  end

  test "renders country stamp as link" do
    render_inline(Ui::StampComponent.new(@country_stamp))

    assert_selector("a[href='/countries/belgium']")
    assert_selector("img[alt='Belgium passport stamp']")
  end

  test "renders contributor stamp as link" do
    render_inline(Ui::StampComponent.new(@contributor_stamp))

    assert_selector("a[href='/contributors']")
    assert_selector("img[alt='RubyEvents Contributor passport stamp']")
  end

  test "renders with default size full" do
    render_inline(Ui::StampComponent.new(@country_stamp))

    assert_selector(".w-full.h-full")
  end

  test "renders with custom size lg" do
    render_inline(Ui::StampComponent.new(@country_stamp, size: :lg))

    assert_selector(".w-20.h-20")
  end

  test "renders with all size variants" do
    Ui::StampComponent::SIZE_MAPPING.except(:unset).keys.each do |size|
      render_inline(Ui::StampComponent.new(@country_stamp, size: size))

      expected_class = Ui::StampComponent::SIZE_MAPPING[size]
      assert_selector(".#{expected_class.split.join(".")}")
    end
  end

  test "renders as static when interactive false" do
    render_inline(Ui::StampComponent.new(@country_stamp, interactive: false))

    refute_selector("a")
  end

  test "applies random rotation" do
    render_inline(Ui::StampComponent.new(@country_stamp, rotate: true))

    assert_selector("img[style*='transform: rotate(']")
  end

  test "uses lazy loading" do
    render_inline(Ui::StampComponent.new(@country_stamp))

    assert_selector("img[loading='lazy']")
  end

  test "applies custom classes" do
    render_inline(Ui::StampComponent.new(@country_stamp, class: "custom-class"))

    assert_selector(".custom-class")
  end

  test "passes through custom attributes" do
    render_inline(Ui::StampComponent.new(@country_stamp, data: {test: "value"}))

    assert_selector("[data-test='value']")
  end
end
