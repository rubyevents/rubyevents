# frozen_string_literal: true

class Ui::DropdownComponent < ApplicationComponent
  renders_many :menu_items, types: {
    divider: lambda { render Ui::DividerComponent.new(class: "my-2") },
    link_to: lambda { |*args, **attributes, &block|
      content_tag :li do
        attributes[:class] = class_names("!whitespace-nowrap", attributes[:class])
        concat link_to(*args, **attributes, &block)
      end
    },
    button_to: lambda { |*args, **attributes|
      content_tag :li do
        attributes[:class] = class_names("!whitespace-nowrap", attributes[:class])
        concat button_to(*args, **attributes)
      end
    }
  }

  renders_one :toggle_open
  renders_one :toggle_close

  OPEN_FROM_MAPPING = {
    left: "dropdown-left",
    right: "dropdown-right",
    top: "dropdown-top",
    bottom: "dropdown-bottom"
  }

  ALIGN_MAPPING = {
    end: "dropdown-end"
  }

  option :open, type: Dry::Types["strict.bool"], default: proc { false }
  option :hover, type: Dry::Types["strict.bool"], default: proc { false }
  option :align, type: Dry::Types["coercible.symbol"].enum(*ALIGN_MAPPING.keys), optional: true
  option :open_from, type: Dry::Types["coercible.symbol"].enum(*OPEN_FROM_MAPPING.keys), optional: true

  private

  def before_render
    attributes[:data] = {controller: "dropdown"}
  end

  def classes
    [component_classes, attributes.delete(:class)].compact_blank.join(" ")
  end

  def component_classes
    class_names(
      "dropdown",
      OPEN_FROM_MAPPING[open_from],
      ALIGN_MAPPING[align],
      "dropdown-hover": hover,
      "dropdown-open": open
    )
  end

  def content_classes
    class_names("dropdown-content menu menu-smp-2 mt-4 w-max z-30 rounded-lg shadow-2xl bg-white text-neutral", attributes.delete(:content_classes))
  end
end
