class DecryptUserName < ActiveRecord::Migration[8.0]
  def up
    User.in_batches(of: 1000) do |batch|
      batch.each do |u|
        plain = u.name
        ActiveRecord::Encryption.without_encryption do
          u.update_columns(name: plain)
        end
      end
    end
  end
end
