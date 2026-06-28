class Avo::Actions::MergeDuplicateAlias < Avo::BaseAction
  self.name = "Merge Duplicate Alias"
  self.confirm_button_label = "Merge"
  self.cancel_button_label = "Cancel"
  self.message = "This will merge the selected users into their main speaker record (based on speakers.yml aliases). Talks, involvements, and profile fields will be transferred. The alias user will be deleted."

  def handle(query:, fields:, current_user:, resource:, **args)
    merged = 0
    skipped = []

    query.each do |record|
      unless record.duplicate_alias?
        skipped << "#{record.name} (#{record.slug}) — not a duplicate alias"
        next
      end

      main_user = record.find_main_speaker
      unless main_user
        skipped << "#{record.name} (#{record.slug}) — main user '#{record.main_speaker_name}' not found"
        next
      end

      if main_user.id == record.id
        skipped << "#{record.name} (#{record.slug}) — same as main user"
        next
      end

      main_user.merge_with!(record)
      merged += 1
    end

    if skipped.any?
      warn "Skipped #{skipped.size}: #{skipped.join("; ")}"
    end

    succeed "Merged #{merged} user(s) into their main speaker records"
  end
end
