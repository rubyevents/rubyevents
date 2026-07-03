# frozen_string_literal: true

class Ui::AvatarGroupComponent < ApplicationComponent
  SIZE_MAPPING = {
    sm: "w-8",
    md: "w-12",
    lg: "w-16"
  }.freeze

  param :avatarables, Dry::Types["strict.array"]
  option :size, Dry::Types["coercible.symbol"].enum(*SIZE_MAPPING.keys), default: proc { :md }
  option :max, Dry::Types["coercible.integer"], default: proc { 8 }
  option :overlap, Dry::Types["coercible.string"], default: proc { "-space-x-3" }
  option :hover_card, type: Dry::Types["strict.bool"], default: proc { false }
  option :linked, type: Dry::Types["strict.bool"], default: proc { false }

  private

  def visible_avatarables
    avatarables.first(max)
  end

  def remaining_count
    [avatarables.size - max, 0].max
  end

  def size_class
    SIZE_MAPPING[size]
  end
end
