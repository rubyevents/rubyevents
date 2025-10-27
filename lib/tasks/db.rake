namespace :database do
  desc "anonymize the database and scrub the database"
  task anonymize_and_scrub: :environment do
    User.all.each do |user|
      user.update_column(:email, "#{user.slug}@rubyevents.org")
    end

    Ahoy::Event.delete_all
    Ahoy::Visit.delete_all
  end
end
