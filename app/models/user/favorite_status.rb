class User::FavoriteStatus
  LABELS = {
    ruby_friend: "Ruby Friend",
    favorite: "Favorite Rubyist"
  }.freeze

  ICONS = {
    ruby_friend: "user-group",
    favorite: "heart"
  }.freeze

  attr_reader :kind

  def initialize(kind)
    @kind = kind.to_sym
  end

  def ruby_friend?
    kind == :ruby_friend
  end

  def favorite?
    kind == :favorite
  end

  def label
    LABELS.fetch(kind)
  end

  def icon
    ICONS.fetch(kind)
  end
end
