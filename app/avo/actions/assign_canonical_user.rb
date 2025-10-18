class Avo::Actions::AssignCanonicalUser < Avo::BaseAction
  self.name = "Assign Canonical User"

  def fields
    field :user_id, as: :select, name: "Canonical user",
      help: "The name of the speaker to be set as canonical",
      options: -> { User.order(:name).pluck(:name, :id) }
  end

  def handle(query:, fields:, current_user:, resource:, **args)
    canonical_user = User.find(fields[:user_id])

    query.each do |record|
      record.assign_canonical_user!(canonical_user: canonical_user)
    end

    succeed "Assigning canonical user #{canonical_user.name} to #{query.count} users"
    redirect_to avo.resources_user_path(canonical_user), status: :permanent_redirect
  end
end
