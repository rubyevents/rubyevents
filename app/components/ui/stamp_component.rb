# frozen_string_literal: true

class Ui::StampComponent < ApplicationComponent
  SIZE_MAPPING = {
    unset: "",
    full: "w-full h-full",
    sm: "w-12 h-12",
    md: "w-16 h-16",
    lg: "w-20 h-20",
    xl: "w-32 h-32"
  }

  param :stamp
  option :size, type: Dry::Types["coercible.symbol"].enum(*SIZE_MAPPING.keys), default: proc { :full }
  option :interactive, type: Dry::Types["strict.bool"], default: proc { true }
  option :rotate, type: Dry::Types["strict.bool"], default: proc { false }
  option :zoom_effect, type: Dry::Types["strict.bool"], default: proc { false }

  def kind
    if stamp.has_country?
      :country
    elsif stamp.has_event?
      :event
    elsif stamp.code == "RUBYEVENTS-CONTRIBUTOR"
      :contributor
    else
      :other
    end
  end

  def clickable?
    [:country, :event, :contributor].include?(kind)
  end

  def url
    case kind
    when :country
      stamp.country.path
    when :event
      stamp.event ? event_path(stamp.event) : nil
    when :contributor
      contributors_path
    when :other
      nil
    end
  end

  def link_attributes
    attributes.except(:class)
  end

  def classes
    [component_classes, attributes[:class]].join(" ")
  end

  def image_style
    transform = []

    transform << "rotate(#{rand(-15..15)}deg)" if rotate
    transform << "scale(#{rand(0.92..0.97)})" if zoom_effect
    "transform: #{transform.join(" ")};"
  end

  def component_classes
    class_names(
      "aspect-square flex items-center justify-center",
      SIZE_MAPPING[size],
      attributes.delete(:class),
      "transition-transform duration-300 lg:hover:!scale-110 lg:hover:!rotate-0": zoom_effect
    )
  end
end
