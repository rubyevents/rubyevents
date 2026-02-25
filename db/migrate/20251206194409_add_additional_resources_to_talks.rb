class AddAdditionalResourcesToTalks < ActiveRecord::Migration[8.1]
  def change
    add_column :talks, :additional_resources, :json, default: [], null: false
  end
end
