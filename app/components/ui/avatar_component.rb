# frozen_string_literal: true

class Ui::AvatarComponent < ApplicationComponent
  SIZE_MAPPING = {
    sm: {
      size_class: "w-8",
      image_size: 48,
      text_size: "text-xs"
    },
    md: {
      size_class: "w-12",
      image_size: 48,
      text_size: "text-lg"
    },
    lg: {
      size_class: "w-40",
      image_size: 200,
      text_size: "text-6xl"
    }
  }.freeze

  KIND_MAPPING = {
    primary: "bg-primary",
    neutral: "bg-neutral"
  }.freeze

  param :avatarable
  option :size, Dry::Types["coercible.symbol"].enum(*SIZE_MAPPING.keys), default: proc { :md }
  option :size_class, Dry::Types["coercible.string"], default: proc { SIZE_MAPPING[size][:size_class] }
  option :outline, type: Dry::Types["strict.bool"], default: proc { false }
  option :kind, Dry::Types["coercible.symbol"].enum(*KIND_MAPPING.keys), default: proc { :primary }

  private

  def image_size
    SIZE_MAPPING[size][:image_size]
  end

  def text_size
    SIZE_MAPPING[size][:text_size]
  end

  def kind_class
    KIND_MAPPING[kind]
  end
end
