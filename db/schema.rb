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

ActiveRecord::Schema[8.2].define(version: 2026_01_03_210603) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.text "properties"
    t.datetime "time"
    t.integer "user_id"
    t.integer "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at"
    t.text "user_agent"
    t.integer "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
  end

  create_table "aliases", force: :cascade do |t|
    t.integer "aliasable_id", null: false
    t.string "aliasable_type", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["aliasable_type", "aliasable_id"], name: "index_aliases_on_aliasable"
    t.index ["aliasable_type", "name"], name: "index_aliases_on_aliasable_type_and_name", unique: true
    t.index ["aliasable_type", "slug"], name: "index_aliases_on_aliasable_type_and_slug", unique: true
  end

  create_table "cfps", force: :cascade do |t|
    t.date "close_date"
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.string "link"
    t.string "name"
    t.date "open_date"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_cfps_on_event_id"
  end

  create_table "connected_accounts", force: :cascade do |t|
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "username"
    t.index ["provider", "uid"], name: "index_connected_accounts_on_provider_and_uid", unique: true
    t.index ["provider", "username"], name: "index_connected_accounts_on_provider_and_username", unique: true
    t.index ["user_id"], name: "index_connected_accounts_on_user_id"
  end

  create_table "contributors", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "html_url"
    t.string "login", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["login"], name: "index_contributors_on_login", unique: true
    t.index ["user_id"], name: "index_contributors_on_user_id"
  end

  create_table "email_verification_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_email_verification_tokens_on_user_id"
  end

  create_table "event_involvements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.integer "involvementable_id", null: false
    t.string "involvementable_type", null: false
    t.integer "position", default: 0
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_involvements_on_event_id"
    t.index ["involvementable_type", "involvementable_id", "event_id", "role"], name: "idx_involvements_on_involvementable_and_event_and_role", unique: true
    t.index ["involvementable_type", "involvementable_id"], name: "index_event_involvements_on_involvementable"
    t.index ["role"], name: "index_event_involvements_on_role"
  end

  create_table "event_participations", force: :cascade do |t|
    t.string "attended_as", null: false
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["attended_as"], name: "index_event_participations_on_attended_as"
    t.index ["event_id"], name: "index_event_participations_on_event_id"
    t.index ["user_id", "event_id", "attended_as"], name: "idx_on_user_id_event_id_attended_as_ca0a2916e2", unique: true
    t.index ["user_id"], name: "index_event_participations_on_user_id"
  end

  create_table "event_series", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.integer "frequency", default: 0, null: false
    t.integer "kind", default: 0, null: false
    t.string "language", default: "", null: false
    t.string "name", default: "", null: false
    t.string "slug", default: "", null: false
    t.string "twitter", default: "", null: false
    t.datetime "updated_at", null: false
    t.string "website", default: "", null: false
    t.string "youtube_channel_id", default: ""
    t.string "youtube_channel_name", default: ""
    t.index ["frequency"], name: "index_event_series_on_frequency"
    t.index ["kind"], name: "index_event_series_on_kind"
    t.index ["name"], name: "index_event_series_on_name"
    t.index ["slug"], name: "index_event_series_on_slug"
  end

  create_table "events", force: :cascade do |t|
    t.integer "canonical_id"
    t.string "city"
    t.string "country_code"
    t.datetime "created_at", null: false
    t.date "date"
    t.string "date_precision", default: "day", null: false
    t.date "end_date"
    t.integer "event_series_id", null: false
    t.string "kind", default: "event", null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", default: "", null: false
    t.string "slug", default: "", null: false
    t.date "start_date"
    t.integer "talks_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "website", default: ""
    t.index ["canonical_id"], name: "index_events_on_canonical_id"
    t.index ["event_series_id"], name: "index_events_on_event_series_id"
    t.index ["kind"], name: "index_events_on_kind"
    t.index ["name"], name: "index_events_on_name"
    t.index ["slug"], name: "index_events_on_slug"
  end

  create_table "llm_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "duration", null: false
    t.json "raw_response", null: false
    t.string "request_hash", null: false
    t.integer "resource_id", null: false
    t.string "resource_type", null: false
    t.boolean "success", default: false, null: false
    t.string "task_name", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["request_hash"], name: "index_llm_requests_on_request_hash", unique: true
    t.index ["resource_type", "resource_id"], name: "index_llm_requests_on_resource"
    t.index ["task_name"], name: "index_llm_requests_on_task_name"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "domain"
    t.integer "kind", default: 0, null: false
    t.string "logo_background", default: "white"
    t.string "logo_url"
    t.json "logo_urls", default: []
    t.string "main_location"
    t.string "name"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["kind"], name: "index_organizations_on_kind"
    t.index ["slug"], name: "index_organizations_on_slug"
  end

  create_table "password_reset_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
  end

  create_table "rollups", force: :cascade do |t|
    t.json "dimensions", default: {}, null: false
    t.string "interval", null: false
    t.string "name", null: false
    t.datetime "time", null: false
    t.float "value"
    t.index ["name", "interval", "time", "dimensions"], name: "index_rollups_on_name_and_interval_and_time_and_dimensions", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "speaker_talks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "speaker_id", null: false
    t.integer "talk_id", null: false
    t.datetime "updated_at", null: false
    t.index ["speaker_id", "talk_id"], name: "index_speaker_talks_on_speaker_id_and_talk_id", unique: true
    t.index ["speaker_id"], name: "index_speaker_talks_on_speaker_id"
    t.index ["talk_id"], name: "index_speaker_talks_on_talk_id"
  end

  create_table "speakers", force: :cascade do |t|
    t.text "bio", default: "", null: false
    t.string "bsky", default: "", null: false
    t.json "bsky_metadata", default: {}, null: false
    t.integer "canonical_id"
    t.datetime "created_at", null: false
    t.string "github", default: "", null: false
    t.json "github_metadata", default: {}, null: false
    t.string "linkedin", default: "", null: false
    t.string "mastodon", default: "", null: false
    t.string "name", default: "", null: false
    t.string "pronouns", default: "", null: false
    t.string "pronouns_type", default: "not_specified", null: false
    t.string "slug", default: "", null: false
    t.string "speakerdeck", default: "", null: false
    t.integer "talks_count", default: 0, null: false
    t.string "twitter", default: "", null: false
    t.datetime "updated_at", null: false
    t.string "website", default: "", null: false
    t.index ["canonical_id"], name: "index_speakers_on_canonical_id"
    t.index ["github"], name: "index_speakers_on_github", unique: true, where: "github IS NOT NULL AND github != ''"
    t.index ["name"], name: "index_speakers_on_name"
    t.index ["slug"], name: "index_speakers_on_slug", unique: true
  end

  create_table "sponsors", force: :cascade do |t|
    t.string "badge"
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.integer "organization_id", null: false
    t.string "tier"
    t.datetime "updated_at", null: false
    t.index ["event_id", "organization_id", "tier"], name: "index_sponsors_on_event_organization_tier_unique", unique: true
    t.index ["event_id"], name: "index_sponsors_on_event_id"
    t.index ["organization_id"], name: "index_sponsors_on_organization_id"
  end

# Could not dump table "sqlite_stat1" because of following StandardError
#   Unknown type '' for column 'idx'


  create_table "suggestions", force: :cascade do |t|
    t.integer "approved_by_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "status", default: 0, null: false
    t.integer "suggestable_id", null: false
    t.string "suggestable_type", null: false
    t.integer "suggested_by_id"
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_suggestions_on_approved_by_id"
    t.index ["status"], name: "index_suggestions_on_status"
    t.index ["suggestable_type", "suggestable_id"], name: "index_suggestions_on_suggestable"
    t.index ["suggested_by_id"], name: "index_suggestions_on_suggested_by_id"
  end

  create_table "talk_topics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "talk_id", null: false
    t.integer "topic_id", null: false
    t.datetime "updated_at", null: false
    t.index ["talk_id"], name: "index_talk_topics_on_talk_id"
    t.index ["topic_id", "talk_id"], name: "index_talk_topics_on_topic_id_and_talk_id", unique: true
    t.index ["topic_id"], name: "index_talk_topics_on_topic_id"
  end

  create_table "talk_transcripts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "enhanced_transcript"
    t.text "raw_transcript"
    t.integer "talk_id", null: false
    t.datetime "updated_at", null: false
    t.index ["talk_id"], name: "index_talk_transcripts_on_talk_id"
  end

  create_table "talks", force: :cascade do |t|
    t.json "additional_resources", default: [], null: false
    t.datetime "announced_at"
    t.datetime "created_at", null: false
    t.date "date"
    t.text "description", default: "", null: false
    t.integer "duration_in_seconds"
    t.integer "end_seconds"
    t.integer "event_id"
    t.boolean "external_player", default: false, null: false
    t.string "external_player_url", default: "", null: false
    t.string "kind", default: "talk", null: false
    t.string "language", default: "en", null: false
    t.integer "like_count", default: 0
    t.boolean "meta_talk", default: false, null: false
    t.string "original_title", default: "", null: false
    t.integer "parent_talk_id"
    t.datetime "published_at"
    t.string "slides_url"
    t.string "slug", default: "", null: false
    t.integer "start_seconds"
    t.string "static_id", null: false
    t.boolean "summarized_using_ai", default: true, null: false
    t.text "summary", default: "", null: false
    t.string "thumbnail_lg", default: "", null: false
    t.string "thumbnail_md", default: "", null: false
    t.string "thumbnail_sm", default: "", null: false
    t.string "thumbnail_xl", default: "", null: false
    t.string "thumbnail_xs", default: "", null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.string "video_id", default: "", null: false
    t.string "video_provider", default: "", null: false
    t.integer "view_count", default: 0
    t.index ["date"], name: "index_talks_on_date"
    t.index ["event_id"], name: "index_talks_on_event_id"
    t.index ["kind"], name: "index_talks_on_kind"
    t.index ["parent_talk_id"], name: "index_talks_on_parent_talk_id"
    t.index ["slug"], name: "index_talks_on_slug"
    t.index ["static_id"], name: "index_talks_on_static_id", unique: true
    t.index ["title"], name: "index_talks_on_title"
    t.index ["updated_at"], name: "index_talks_on_updated_at"
    t.index ["video_provider", "date"], name: "index_talks_on_video_provider_and_date"
  end

  create_table "topics", force: :cascade do |t|
    t.integer "canonical_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.boolean "published", default: false
    t.string "slug", default: "", null: false
    t.string "status", default: "pending", null: false
    t.integer "talks_count"
    t.datetime "updated_at", null: false
    t.index ["canonical_id"], name: "index_topics_on_canonical_id"
    t.index ["name"], name: "index_topics_on_name", unique: true
    t.index ["slug"], name: "index_topics_on_slug"
    t.index ["status"], name: "index_topics_on_status"
  end

  create_table "user_talks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.integer "talk_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["talk_id"], name: "index_user_talks_on_talk_id"
    t.index ["user_id", "talk_id"], name: "index_user_talks_on_user_id_and_talk_id", unique: true
    t.index ["user_id"], name: "index_user_talks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.text "bio", default: "", null: false
    t.string "bsky", default: "", null: false
    t.json "bsky_metadata", default: {}, null: false
    t.integer "canonical_id"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "github_handle"
    t.json "github_metadata", default: {}, null: false
    t.string "linkedin", default: "", null: false
    t.string "location", default: ""
    t.boolean "marked_for_deletion", default: false, null: false
    t.string "mastodon", default: "", null: false
    t.string "name"
    t.string "password_digest"
    t.string "pronouns", default: "", null: false
    t.string "pronouns_type", default: "not_specified", null: false
    t.json "settings", default: {}, null: false
    t.string "slug", default: "", null: false
    t.string "speakerdeck", default: "", null: false
    t.integer "talks_count", default: 0, null: false
    t.string "twitter", default: "", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.integer "watched_talks_count", default: 0, null: false
    t.string "website", default: "", null: false
    t.index "lower(github_handle)", name: "index_users_on_lower_github_handle", unique: true, where: "github_handle IS NOT NULL AND github_handle != ''"
    t.index ["canonical_id"], name: "index_users_on_canonical_id"
    t.index ["email"], name: "index_users_on_email"
    t.index ["marked_for_deletion"], name: "index_users_on_marked_for_deletion"
    t.index ["name"], name: "index_users_on_name"
    t.index ["slug"], name: "index_users_on_slug", unique: true, where: "slug IS NOT NULL AND slug != ''"
  end

  create_table "watch_list_talks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "talk_id", null: false
    t.datetime "updated_at", null: false
    t.integer "watch_list_id", null: false
    t.index ["talk_id"], name: "index_watch_list_talks_on_talk_id"
    t.index ["watch_list_id", "talk_id"], name: "index_watch_list_talks_on_watch_list_id_and_talk_id", unique: true
    t.index ["watch_list_id"], name: "index_watch_list_talks_on_watch_list_id"
  end

  create_table "watch_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "talks_count", default: 0
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_watch_lists_on_user_id"
  end

  create_table "watched_talks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "feedback", default: {}
    t.datetime "feedback_shared_at"
    t.integer "progress_seconds", default: 0, null: false
    t.integer "talk_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.boolean "watched", default: false, null: false
    t.datetime "watched_at", null: false
    t.string "watched_on"
    t.index ["talk_id", "user_id"], name: "index_watched_talks_on_talk_id_and_user_id", unique: true
    t.index ["talk_id"], name: "index_watched_talks_on_talk_id"
    t.index ["user_id"], name: "index_watched_talks_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cfps", "events"
  add_foreign_key "connected_accounts", "users"
  add_foreign_key "contributors", "users"
  add_foreign_key "email_verification_tokens", "users"
  add_foreign_key "event_involvements", "events"
  add_foreign_key "event_participations", "events"
  add_foreign_key "event_participations", "users"
  add_foreign_key "events", "event_series"
  add_foreign_key "events", "events", column: "canonical_id"
  add_foreign_key "password_reset_tokens", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "speakers", "speakers", column: "canonical_id"
  add_foreign_key "sponsors", "events"
  add_foreign_key "sponsors", "organizations"
  add_foreign_key "suggestions", "users", column: "approved_by_id"
  add_foreign_key "suggestions", "users", column: "suggested_by_id"
  add_foreign_key "talk_topics", "talks"
  add_foreign_key "talk_topics", "topics"
  add_foreign_key "talk_transcripts", "talks"
  add_foreign_key "talks", "events"
  add_foreign_key "talks", "talks", column: "parent_talk_id"
  add_foreign_key "topics", "topics", column: "canonical_id"
  add_foreign_key "user_talks", "talks"
  add_foreign_key "user_talks", "users"
  add_foreign_key "watch_list_talks", "talks"
  add_foreign_key "watch_list_talks", "watch_lists"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "speakers_search_index", "fts5", ["name", "github", "tokenize = porter"]
  create_virtual_table "talks_search_index", "fts5", ["title", "summary", "speaker_names", "event_names", "tokenize = porter"]
  create_virtual_table "users_search_index", "fts5", ["name", "github_handle", "tokenize = porter"]
end
