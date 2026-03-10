class CreateInboundEmails < ActiveRecord::Migration[7.1]
  def change
    create_table :inbound_emails do |t|
      t.references :job, null: false, foreign_key: true
      t.string :message_id
      t.string :from
      t.string :to
      t.string :cc
      t.string :subject
      t.text :text_body
      t.text :html_body
      t.datetime :received_at
      t.string :status
      t.jsonb :headers
      t.text :error_message

      t.timestamps
    end
  end
end
