# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_03_10_203725) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "inbound_emails", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "message_id"
    t.string "from"
    t.string "to"
    t.string "cc"
    t.string "subject"
    t.text "text_body"
    t.text "html_body"
    t.datetime "received_at"
    t.string "status"
    t.jsonb "headers"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_inbound_emails_on_job_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "job_type"
    t.string "token", null: false
    t.string "pretty_name"
    t.string "pretty_email"
    t.string "user_email"
    t.string "status", default: "active", null: false
    t.text "instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_type"], name: "index_jobs_on_job_type"
    t.index ["pretty_email"], name: "index_jobs_on_pretty_email", unique: true
    t.index ["status"], name: "index_jobs_on_status"
    t.index ["token"], name: "index_jobs_on_token", unique: true
    t.index ["user_email"], name: "index_jobs_on_user_email", unique: true
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "inbound_emails", "jobs"
  add_foreign_key "jobs", "users"
end
