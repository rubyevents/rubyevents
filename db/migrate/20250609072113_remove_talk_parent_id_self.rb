class RemoveTalkParentIdSelf < ActiveRecord::Migration[8.0]
  def change
    Talk.where("parent_talk_id = id").update_all(parent_talk_id: nil)
  end
end
