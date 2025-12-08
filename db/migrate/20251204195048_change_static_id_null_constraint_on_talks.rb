class ChangeStaticIdNullConstraintOnTalks < ActiveRecord::Migration[8.1]
  def change
    change_column_null :talks, :static_id, false
  end
end
