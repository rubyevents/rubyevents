class SetViewCountDefaultOnTalk < ActiveRecord::Migration[8.0]
  def change
    change_column_default :talks, :view_count, 0
    change_column_default :talks, :like_count, 0
  end
end
