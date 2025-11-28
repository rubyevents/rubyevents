# id           :integer
# uid          :string
# provider     :string
# username     :string
# user_id      :integer
# access_token :string
# expires_at   :datetime
# created_at   :datetime
# updated_at   :datetime

class Avo::Resources::ConnectedAccount < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  self.search = {
    query: -> { query.ransack(id_eq: params[:q], uid_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :id
    field :uid, as: :text
    field :provider, as: :text, sortable: true
    field :username, as: :text, sortable: true
    field :user, as: :belongs_to, sortable: true
    field :user_id, as: :text, sortable: true, hide_on: [:index]
    field :access_token, as: :text, hide_on: [:index]
    field :expires_at, as: :date_time, hide_on: [:index]
    field :created_at, as: :date_time, hide_on: [:index]
    field :updated_at, as: :date_time, hide_on: [:index]
  end

  def filters
    filter Avo::Filters::Provider
  end
end
