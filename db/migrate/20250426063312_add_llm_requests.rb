class AddLLMRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :llm_requests do |t|
      t.string :request_hash, null: false, index: {unique: true}
      t.json :raw_response, null: false
      t.float :duration, null: false
      t.references :resource, polymorphic: true, null: false
      t.timestamps
    end
  end
end
