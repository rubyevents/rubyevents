class AddSuccessToLLMRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :llm_requests, :success, :boolean, null: false, default: false
    add_column :llm_requests, :task_name, :string, null: false, default: ""

    add_index :llm_requests, :task_name
  end
end
