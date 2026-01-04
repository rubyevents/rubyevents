class Avo::Resources::TopicGem < Avo::BaseResource
  self.search = {
    query: -> { query.where("gem_name LIKE ?", "%#{params[:q]}%") }
  }

  def fields
    field :id, as: :id
    field :topic, as: :belongs_to
    field :gem_name, as: :text, help: "Exact gem name from RubyGems.org (e.g., 'sidekiq', 'activerecord')"
  end
end
