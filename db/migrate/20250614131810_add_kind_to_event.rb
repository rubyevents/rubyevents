class AddKindToEvent < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :kind, :string, default: "event", null: false
    add_index :events, :kind

    Event.find_in_batches.each do |events|
      events.each do |event|
        if event.static_metadata.meetup?
          event.update!(kind: "meetup")
        elsif event.static_metadata.conference?
          event.update!(kind: "conference")
        else
          event.update!(kind: "event")
        end
      end
    end
  end

  def down
    remove_index :events, :kind
    remove_column :events, :kind
  end
end
