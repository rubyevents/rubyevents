class Avo::Actions::ClearUser < Avo::BaseAction
  self.name = "Clear Suspicion"
  self.message = "Mark this user as manually reviewed and not suspicious."

  def handle(query:, fields:, current_user:, resource:, **args)
    query.each do |user|
      user.clear_suspicion!
    end

    succeed "Cleared suspicion for #{query.count} user(s)."
  end
end
