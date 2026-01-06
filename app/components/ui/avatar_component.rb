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
      image_size: 96,
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
  option :hover_card, type: Dry::Types["strict.bool"], default: proc { false }
  option :linked, type: Dry::Types["strict.bool"], default: proc { false }

  def show_hover_card?
    hover_card && avatarable.is_a?(User)
  end

  def show_link?
    linked && avatarable.present?
  end

  def link_path
    return nil unless avatarable.present?

    if avatarable.is_a?(User)
      helpers.profile_path(avatarable)
    elsif avatarable.respond_to?(:slug)
      helpers.speaker_path(avatarable)
    end
  end

  def avatar_classes
    [
      size_class,
      "rounded-full",
      kind_class,
      "text-neutral-content",
      (outline ? "outline outline-2" : nil)
    ].compact.join(" ")
  end

  def initials
    return "" unless avatarable&.name.present?
    avatarable.name.split(" ").map(&:first).join
  end

  def has_custom_avatar?
    avatarable&.respond_to?(:custom_avatar?) && avatarable.custom_avatar?
  end

  def avatar_url_for_size
    avatarable.avatar_url(size: image_size)
  end

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

  def suspicious?
    avatarable && avatarable.respond_to?(:suspicious?) && avatarable.suspicious?
  end

  def show_custom_avatar?
    avatarable && avatarable.custom_avatar? && !suspicious?
  end
end
