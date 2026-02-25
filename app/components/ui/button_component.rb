# frozen_string_literal: true

class Ui::ButtonComponent < ApplicationComponent
  KIND_MAPPING = {
    primary: "btn-primary",
    secondary: "btn-secondary",
    neutral: "btn-neutral btn-outline",
    rounded: "btn btn-rounded",
    pill: "btn btn-pill btn-sm",
    circle: "btn btn-circle",
    ghost: "btn-ghost",
    link: "btn-link",
    none: ""
  }

  SIZE_MAPPING = {
    sm: "btn-sm",
    md: "",
    lg: "btn-lg"
  }

  param :text, default: proc {}
  option :url, Dry::Types["coercible.string"], optional: true
  option :method, Dry::Types["coercible.symbol"].enum(:get, :post, :patch, :put, :delete), optional: true
  option :kind, type: Dry::Types["coercible.symbol"].enum(*KIND_MAPPING.keys), default: proc { :primary }
  option :size, type: Dry::Types["coercible.symbol"].enum(*SIZE_MAPPING.keys), default: proc { :md }
  option :type, type: Dry::Types["coercible.symbol"].enum(:button, :submit, :input), default: proc { :button }
  option :disabled, type: Dry::Types["strict.bool"], default: proc { false }
  option :outline, type: Dry::Types["strict.bool"], default: proc { false }
  option :animation, type: Dry::Types["strict.bool"], default: proc { false }

  def call
    case button_kind
    when :link
      link_to(url, disabled: disabled, class: classes, **attributes.except(:class, :type)) { content }
    when :button_to
      button_to(url, disabled: disabled, method: method, class: classes, **attributes.except(:class, :type)) { content }
    when :button
      tag.button(type: type, disabled: disabled, class: classes, **attributes.except(:class, :type)) { content }
    end
  end

  private

  def classes
    [component_classes, attributes[:class]].join(" ")
  end

  def component_classes
    class_names(
      "btn",
      KIND_MAPPING[kind],
      SIZE_MAPPING[size],
      "btn-outline": outline,
      "btn-disabled": disabled,
      "no-animation": !animation # animation is disabled by default, I don't really like the effect when you enter the page
    )
  end

  def content
    text.presence || super
  end

  def button_kind
    return :link if url.present? && default_method?
    return :button_to if url.present? && !default_method?

    :button
  end

  def default_method?
    method.blank? || method == :get
  end
end
