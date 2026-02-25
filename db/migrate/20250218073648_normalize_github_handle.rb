class NormalizeGitHubHandle < ActiveRecord::Migration[8.0]
  def change
    User.all.each do |u|
      next if u.github_handle.blank?
      u.update_column(:github_handle, u.github_handle.strip.downcase)
    end

    ConnectedAccount.all.each do |ca|
      next if ca.username.blank?

      ca.update_column(:username, ca.username.strip.downcase)
    end

    Speaker.where.not(github: [nil, ""]).each do |s|
      s.update_column(:github, s.github.strip.downcase)
    end
  end
end
