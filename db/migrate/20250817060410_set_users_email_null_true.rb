class SetUsersEmailNullTrue < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :email, true
    change_column_null :users, :password_digest, true
  end
end
