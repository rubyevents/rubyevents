namespace :users do
  desc "Move user to speaker"
  task transfer_all_to_speaker: :environment do
    User.find_each do |user|
      next if user.github_handle.blank?

      speaker = Speaker.find_or_initialize_by(github: user.github_handle)
      speaker.update!(
        email: user.email,
        name: user.name,
        password_digest:
        user.password_digest,
        admin: user.admin
      )
    end
  end
end
