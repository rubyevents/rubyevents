class Avo::Resources::TopicGem < Avo::BaseResource
  self.title = :gem_name
  self.search = {
    query: -> { query.where("gem_name LIKE ?", "%#{params[:q]}%") }
  }
  self.external_link = -> {
    record.rubygems_url
  }

  def self.name
    "Gem"
  end

  def fields
    field :id, as: :id
    field :gem_name, as: :text, link_to_record: true, help: "Exact gem name from RubyGems.org (e.g., 'sidekiq', 'activerecord')"
    field :topic, as: :belongs_to, link_to_record: true
  end
end
