# to dump the db:
# first stop the app and all processes that are using the db
# then bin/dump_prod.sh
# then rake db:anonymize_and_compact

namespace :db do
  desc "compact the db and anonymize the email addresses"
  task anonymize_and_compact: :environment do
    raise unless Rails.env.development?

    puts "Deleting Ahoy events and visits"
    Ahoy::Event.delete_all
    puts "Deleting Ahoy visits"
    Ahoy::Visit.delete_all

    puts "Anonymizing email addresses and decrypting email addresses"
    User.all.each do |user|
      user.update_column(:email, "#{user.slug}@rubyevents.org")
    end

    puts "Vacuuming the db"
    ActiveRecord::Base.connection.execute("VACUUM")
    puts "Done"

    db_path = ActiveRecord::Base.connection_db_config.database
    db_size_bytes = File.size(db_path)
    db_size_gb = db_size_bytes / (1024.0**3)
    puts "The db file size is #{db_size_gb.round(2)} GB (#{db_size_bytes} bytes)"
  end
end
