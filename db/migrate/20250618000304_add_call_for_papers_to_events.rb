class AddCallForPapersToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :call_for_papers_link, :string
    add_column :events, :call_for_papers_deadline, :date
  end
end
