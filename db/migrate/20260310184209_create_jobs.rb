class CreateJobs < ActiveRecord::Migration[7.1]
  def change
    create_table :jobs do |t|
      t.references :user, null: false, foreign_key: true

      t.string :name, null: false
      t.text :description

      t.string :job_type
      t.string :token, null: false
      t.string :pretty_name
      t.string :pretty_email
      t.string :user_email

      t.string :status, null: false, default: "active"
      t.text :instructions

      t.timestamps
    end

    add_index :jobs, :token, unique: true
    add_index :jobs, :pretty_email, unique: true
    add_index :jobs, :user_email, unique: true
    add_index :jobs, :job_type
    add_index :jobs, :status
  end
end