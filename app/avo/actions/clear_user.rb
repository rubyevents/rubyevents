class Avo::Actions::ClearUser < Avo::BaseAction
  self.name = "Clear Suspicious"
  self.message = "Mark this user as manually reviewed and not suspicious."

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |user|
      user.clear!
    end

    succeed "Cleared #{query.count} user(s) as not suspicious."
  end
end
