namespace :backfill do
  desc "Backfill EventInvolvement records from involvements.yml files"
  task event_involvements: :environment do
    puts "Starting backfill of event involvement records from YAML files..."

    created_count = 0
    error_count = 0
    events_processed = 0

    Organisation.find_each do |organisation|
      Event.where(organisation: organisation).find_each do |event|
        involvements_path = Rails.root.join("data", organisation.slug, event.slug, "involvements.yml")

        next unless File.exist?(involvements_path)

        events_processed += 1
        puts "\nProcessing #{event.name}..."

        deleted_count = event.event_involvements.count
        event.event_involvements.destroy_all

        puts "Deleted #{deleted_count} existing involvements" if deleted_count > 0

        involvements = YAML.load_file(involvements_path)

        involvements.each do |involvement_group|
          role = involvement_group["name"]

          involvement_group["users"]&.each_with_index do |user_name, index|
            next if user_name.blank?

            user = User.find_by(name: user_name)
            unless user
              puts "\nCreating user: #{user_name}"
              user = User.create!(name: user_name)
            end

            involvement = EventInvolvement.find_or_initialize_by(
              involvementable: user,
              event: event,
              role: role
            )
            involvement.position = index

            if involvement.save
              created_count += 1 if involvement.previously_new_record?
              print "."
            else
              puts "\nFailed to create involvement for user #{user_name} in #{event.name}: #{involvement.errors.full_messages.join(", ")}"
              error_count += 1
            end
          end

          involvement_group["organisations"]&.each_with_index do |org_name, index|
            next if org_name.blank?

            sponsor = Sponsor.find_by(name: org_name)
            unless sponsor
              puts "\nCreating sponsor: #{org_name}"
              sponsor = Sponsor.create!(name: org_name)
            end

            user_count = involvement_group["users"]&.compact&.size || 0

            involvement = EventInvolvement.find_or_initialize_by(
              involvementable: sponsor,
              event: event,
              role: role
            )
            involvement.position = user_count + index

            if involvement.save
              created_count += 1 if involvement.previously_new_record?
              print "."
            else
              puts "\nFailed to create involvement for sponsor #{org_name} in #{event.name}: #{involvement.errors.full_messages.join(", ")}"
              error_count += 1
            end
          end
        end
      rescue => e
        puts "\nError processing event #{event.name}: #{e.message}"
        error_count += 1
      end
    end

    puts "\n\nBackfill completed!"
    puts "Events processed: #{events_processed}"
    puts "New involvements created: #{created_count}"
    puts "Errors: #{error_count}"
  end
end
