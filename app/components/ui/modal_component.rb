# frozen_string_literal: true

class Ui::ModalComponent < ApplicationComponent
  POSITION_MAPPING = {
    top: "modal-top",
    bottom: "modal-bottom",
    middle: "modal-middle",
    responsive: "modal-bottom sm:modal-middle"
  }

  SIZE_MAPPING = {
    md: "",
    lg: "!max-w-[800px]"
  }

  option :open, type: Dry::Types["strict.bool"], default: proc { false }
  option :close_button, type: Dry::Types["strict.bool"], default: proc { true }
  option :position, type: Dry::Types["coercible.symbol"].enum(*POSITION_MAPPING.keys), optional: true, default: proc { :responsive }
  option :size, type: Dry::Types["coercible.symbol"].enum(*SIZE_MAPPING.keys), optional: true, default: proc { :md }

  private

  def before_render
    default_action = "keydown.esc->modal#close"
    custom_action = attributes[:data]&.delete(:action)
    combined_action = [default_action, custom_action].compact.join(" ")

    attributes[:data] = {
      controller: "modal",
      modal_open_value: open,
      turbo_temporary: true,
      action: combined_action
    }.merge(attributes[:data] || {})
  end

  def classes
    [component_classes, attributes.delete(:class)].compact_blank.join(" ")
  end

  def component_classes
    class_names(
      "modal",
      POSITION_MAPPING[position]
    )
  end

  def size_class
    SIZE_MAPPING[size]
  end

  def content_classes
    class_names("dropdown-content menu menu-sm p-2 mt-4 w-max z-[1] rounded-lg shadow-2xl bg-white text-neutral", attributes.delete(:content_classes))
  end
end
