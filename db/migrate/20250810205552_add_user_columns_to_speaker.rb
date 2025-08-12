class AddUserColumnsToSpeaker < ActiveRecord::Migration[8.0]
  def change
    add_column :speakers, :admin, :boolean, default: false, null: false
    add_column :speakers, :password_digest, :string
    add_column :speakers, :email, :string
  end
end
