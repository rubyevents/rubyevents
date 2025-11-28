class Avo::Actions::UserFetchGitHub < Avo::BaseAction
  self.name = "Fetch GitHub profile"

  def handle(query:, fields:, current_user:, resource:, **args)
    perform_in_background = !(query.count < 10)
    query.each do |user|
      perform_in_background ? user.profiles.enhance_with_github_later : user.profiles.enhance_with_github
    end
  end
end
