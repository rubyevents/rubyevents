class CreateImportedFiles < ActiveRecord::Migration[8.2]
  def change
    create_table :imported_files do |t|
      t.string :file_path, null: false
      t.string :fingerprint, null: false

      t.timestamps
    end

    add_index :imported_files, :file_path, unique: true
  end
end
