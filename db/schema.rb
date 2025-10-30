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

ActiveRecord::Schema[8.0].define(version: 2025_10_30_203526) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bicycles", force: :cascade do |t|
    t.string "name", null: false
    t.string "notes"
    t.boolean "active", default: true
    t.string "strava_gear_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_bicycles_on_active"
    t.index ["strava_gear_id"], name: "index_bicycles_on_strava_gear_id"
  end

  create_table "books", force: :cascade do |t|
    t.string "title", null: false
    t.string "author", null: false
    t.integer "status", default: 0, null: false
    t.date "started_on"
    t.date "finished_on"
    t.integer "times_read", default: 0, null: false
    t.decimal "rating", precision: 2, scale: 1
    t.integer "progress"
    t.string "isbn"
    t.string "isbn13"
    t.string "hardcover_id"
    t.string "goodreads_id"
    t.string "series"
    t.integer "series_position"
    t.integer "page_count"
    t.integer "published_year"
    t.string "publisher"
    t.text "description"
    t.jsonb "metadata", default: {}
    t.boolean "cover_manually_uploaded", default: false
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author"], name: "index_books_on_author"
    t.index ["finished_on"], name: "index_books_on_finished_on"
    t.index ["goodreads_id"], name: "index_books_on_goodreads_id"
    t.index ["hardcover_id"], name: "index_books_on_hardcover_id", unique: true
    t.index ["series"], name: "index_books_on_series"
    t.index ["status", "finished_on"], name: "index_books_on_status_and_finished_on"
    t.index ["status"], name: "index_books_on_status"
  end

  create_table "concert_artists", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_concert_artists_on_name", unique: true
  end

  create_table "concert_performances", force: :cascade do |t|
    t.bigint "concert_id", null: false
    t.bigint "concert_artist_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concert_artist_id"], name: "index_concert_performances_on_concert_artist_id"
    t.index ["concert_id", "concert_artist_id"], name: "index_concert_performances_uniqueness", unique: true
    t.index ["concert_id", "position"], name: "index_concert_performances_on_concert_id_and_position"
    t.index ["concert_id"], name: "index_concert_performances_on_concert_id"
  end

  create_table "concert_venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "city"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city", "state"], name: "index_concert_venues_on_city_and_state"
    t.index ["name"], name: "index_concert_venues_on_name"
  end

  create_table "concerts", force: :cascade do |t|
    t.date "played_on", null: false
    t.text "notes"
    t.bigint "concert_venue_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["concert_venue_id"], name: "index_concerts_on_concert_venue_id"
    t.index ["played_on"], name: "index_concerts_on_played_on"
  end

  create_table "log_entries", force: :cascade do |t|
    t.string "loggable_type"
    t.bigint "loggable_id"
    t.string "category", null: false
    t.string "level", default: "info"
    t.string "event"
    t.text "message"
    t.jsonb "data", default: {}
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.index ["category", "created_at"], name: "index_log_entries_on_category_and_created_at"
    t.index ["category", "level", "created_at"], name: "index_log_entries_on_category_and_level_and_created_at"
    t.index ["loggable_type", "loggable_id", "created_at"], name: "index_log_entries_on_loggable_and_created"
    t.index ["loggable_type", "loggable_id"], name: "index_log_entries_on_loggable"
    t.index ["user_id"], name: "index_log_entries_on_user_id"
  end

  create_table "milestones", force: :cascade do |t|
    t.bigint "bicycle_id", null: false
    t.date "occurred_on", null: false
    t.string "title", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bicycle_id", "occurred_on"], name: "index_milestones_on_bicycle_id_and_occurred_on"
    t.index ["bicycle_id"], name: "index_milestones_on_bicycle_id"
    t.index ["occurred_on"], name: "index_milestones_on_occurred_on"
  end

  create_table "movie_posters", force: :cascade do |t|
    t.bigint "movie_id", null: false
    t.text "url"
    t.boolean "primary", default: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.index ["movie_id", "primary"], name: "index_movie_posters_on_movie_id_and_primary"
    t.index ["movie_id", "url"], name: "index_movie_posters_on_movie_id_and_url", unique: true
    t.index ["movie_id"], name: "index_movie_posters_on_movie_id"
    t.index ["position"], name: "index_movie_posters_on_position"
  end

  create_table "movies", force: :cascade do |t|
    t.string "title", null: false
    t.string "director"
    t.integer "year"
    t.decimal "rating", precision: 2, scale: 1
    t.decimal "score", precision: 5, scale: 2
    t.string "letterboxd_id"
    t.string "tmdb_id"
    t.datetime "last_synced_at"
    t.text "review"
    t.text "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["letterboxd_id"], name: "index_movies_on_letterboxd_id", unique: true
    t.index ["title"], name: "index_movies_on_title"
    t.index ["tmdb_id"], name: "index_movies_on_tmdb_id"
    t.index ["year"], name: "index_movies_on_year"
  end

  create_table "nba_games", force: :cascade do |t|
    t.bigint "away_id", null: false
    t.bigint "home_id", null: false
    t.date "played_on", null: false
    t.datetime "played_at"
    t.string "gametime"
    t.string "season"
    t.boolean "preseason", default: false
    t.boolean "postseason", default: false
    t.integer "playoff_round"
    t.string "playoff_conference"
    t.integer "playoff_series_game_number"
    t.integer "away_score"
    t.integer "home_score"
    t.integer "overtimes", default: 0
    t.integer "quarters_watched", default: 0
    t.string "network"
    t.string "screen"
    t.string "place"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["away_id"], name: "index_nba_games_on_away_id"
    t.index ["home_id"], name: "index_nba_games_on_home_id"
    t.index ["played_on", "away_id", "home_id"], name: "index_nba_games_uniqueness", unique: true
    t.index ["played_on", "position"], name: "index_nba_games_on_played_on_and_position"
    t.index ["played_on"], name: "index_nba_games_on_played_on"
    t.index ["playoff_round", "playoff_conference"], name: "index_nba_games_on_playoff_round_and_playoff_conference"
    t.index ["postseason"], name: "index_nba_games_on_postseason"
    t.index ["quarters_watched"], name: "index_nba_games_on_quarters_watched"
    t.index ["season"], name: "index_nba_games_on_season"
  end

  create_table "nba_teams", force: :cascade do |t|
    t.string "city", null: false
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.string "color"
    t.string "conference"
    t.string "division"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_nba_teams_on_abbreviation", unique: true
    t.index ["active"], name: "index_nba_teams_on_active"
    t.index ["name"], name: "index_nba_teams_on_name"
  end

  create_table "rides", force: :cascade do |t|
    t.bigint "bicycle_id", null: false
    t.bigint "strava_activity_id"
    t.date "rode_on", null: false
    t.decimal "miles", precision: 5, scale: 2
    t.integer "duration"
    t.string "notes"
    t.bigint "strava_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bicycle_id", "rode_on"], name: "index_rides_on_bicycle_id_and_rode_on"
    t.index ["bicycle_id"], name: "index_rides_on_bicycle_id"
    t.index ["rode_on"], name: "index_rides_on_rode_on"
    t.index ["strava_activity_id"], name: "index_rides_on_strava_activity_id"
    t.index ["strava_id"], name: "index_rides_on_strava_id"
  end

  create_table "scrobble_albums", force: :cascade do |t|
    t.string "name"
    t.bigint "scrobble_artist_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scrobble_artists", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scrobble_counts", force: :cascade do |t|
    t.date "played_on"
    t.integer "plays"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scrobble_plays", force: :cascade do |t|
    t.bigint "scrobble_artist_id"
    t.bigint "scrobble_album_id"
    t.integer "plays"
    t.date "played_on"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "spotify_artists", force: :cascade do |t|
    t.string "spotify_id", null: false
    t.string "name", null: false
    t.string "sort_name"
    t.string "spotify_url"
    t.integer "followers_count"
    t.integer "popularity"
    t.string "image_url"
    t.jsonb "genres", default: []
    t.jsonb "spotify_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_spotify_artists_on_name"
    t.index ["sort_name"], name: "index_spotify_artists_on_sort_name"
    t.index ["spotify_id"], name: "index_spotify_artists_on_spotify_id", unique: true
  end

  create_table "spotify_playlist_tracks", force: :cascade do |t|
    t.bigint "spotify_playlist_id", null: false
    t.bigint "spotify_track_id", null: false
    t.integer "position", null: false
    t.datetime "added_at"
    t.string "added_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["spotify_playlist_id", "position"], name: "idx_on_spotify_playlist_id_position_ede41ceac7"
    t.index ["spotify_playlist_id", "spotify_track_id"], name: "index_playlist_tracks_unique", unique: true
    t.index ["spotify_playlist_id"], name: "index_spotify_playlist_tracks_on_spotify_playlist_id"
    t.index ["spotify_track_id"], name: "index_spotify_playlist_tracks_on_spotify_track_id"
  end

  create_table "spotify_playlists", force: :cascade do |t|
    t.string "name", null: false
    t.string "spotify_url", null: false
    t.string "spotify_id"
    t.string "made_by"
    t.boolean "mixtape", default: false
    t.date "made_on"
    t.integer "year"
    t.integer "month"
    t.integer "runtime_ms", default: 0
    t.string "owner_name"
    t.string "owner_id"
    t.text "description"
    t.boolean "public"
    t.boolean "collaborative", default: false
    t.integer "followers_count", default: 0
    t.string "image_url"
    t.string "snapshot_id"
    t.jsonb "spotify_data", default: {}
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_modified_at"
    t.string "previous_snapshot_id"
    t.index ["last_modified_at"], name: "index_spotify_playlists_on_last_modified_at"
    t.index ["made_on"], name: "index_spotify_playlists_on_made_on"
    t.index ["mixtape"], name: "index_spotify_playlists_on_mixtape"
    t.index ["previous_snapshot_id"], name: "index_spotify_playlists_on_previous_snapshot_id"
    t.index ["spotify_id"], name: "index_spotify_playlists_on_spotify_id", unique: true
    t.index ["spotify_url"], name: "index_spotify_playlists_on_spotify_url"
    t.index ["year", "month"], name: "index_spotify_playlists_on_year_and_month"
  end

  create_table "spotify_track_artists", force: :cascade do |t|
    t.bigint "spotify_track_id", null: false
    t.bigint "spotify_artist_id", null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["spotify_artist_id"], name: "index_spotify_track_artists_on_spotify_artist_id"
    t.index ["spotify_track_id", "spotify_artist_id"], name: "index_track_artists_unique", unique: true
    t.index ["spotify_track_id"], name: "index_spotify_track_artists_on_spotify_track_id"
  end

  create_table "spotify_tracks", force: :cascade do |t|
    t.string "spotify_id", null: false
    t.string "title", null: false
    t.string "artist_text"
    t.string "artist_sort_text"
    t.string "album"
    t.string "album_id"
    t.integer "disc_number"
    t.integer "track_number"
    t.integer "popularity"
    t.integer "duration_ms"
    t.boolean "explicit", default: false
    t.string "song_url"
    t.string "album_url"
    t.string "preview_url"
    t.string "isrc"
    t.jsonb "audio_features", default: {}
    t.jsonb "spotify_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "album_image_url"
    t.date "release_date"
    t.string "release_date_precision"
    t.integer "release_year"
    t.index ["album"], name: "index_spotify_tracks_on_album"
    t.index ["album_image_url"], name: "index_spotify_tracks_on_album_image_url"
    t.index ["artist_sort_text"], name: "index_spotify_tracks_on_artist_sort_text"
    t.index ["popularity"], name: "index_spotify_tracks_on_popularity"
    t.index ["release_date"], name: "index_spotify_tracks_on_release_date"
    t.index ["release_year"], name: "index_spotify_tracks_on_release_year"
    t.index ["spotify_id"], name: "index_spotify_tracks_on_spotify_id", unique: true
  end

  create_table "strava_activities", force: :cascade do |t|
    t.string "name"
    t.bigint "strava_id", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "moving_time"
    t.integer "elapsed_time"
    t.decimal "distance", precision: 7, scale: 1
    t.decimal "distance_in_miles", precision: 5, scale: 2
    t.string "activity_type"
    t.boolean "commute", default: false
    t.string "gear_id"
    t.string "city"
    t.string "state"
    t.boolean "private", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type"], name: "index_strava_activities_on_activity_type"
    t.index ["commute"], name: "index_strava_activities_on_commute"
    t.index ["gear_id"], name: "index_strava_activities_on_gear_id"
    t.index ["started_at"], name: "index_strava_activities_on_started_at"
    t.index ["strava_id"], name: "index_strava_activities_on_strava_id", unique: true
  end

  create_table "sync_statuses", force: :cascade do |t|
    t.string "source_type", null: false
    t.string "status", default: "pending"
    t.integer "total_items"
    t.integer "processed_items", default: 0
    t.integer "created_count", default: 0
    t.integer "updated_count", default: 0
    t.integer "failed_count", default: 0
    t.integer "skipped_count", default: 0
    t.text "error_message"
    t.jsonb "metadata", default: {}
    t.boolean "interactive", default: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["source_type", "created_at"], name: "index_sync_statuses_on_source_type_and_created_at"
    t.index ["source_type"], name: "index_sync_statuses_on_source_type"
    t.index ["user_id"], name: "index_sync_statuses_on_user_id"
  end

  create_table "top_scrobbles", force: :cascade do |t|
    t.string "category"
    t.string "period"
    t.text "artist"
    t.text "name"
    t.integer "rank"
    t.integer "plays"
    t.integer "position"
    t.datetime "revised_at"
    t.text "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "uploads", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.boolean "admin", default: false, null: false
    t.string "provider"
    t.string "uid"
    t.string "image"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["name"], name: "index_users_on_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "viewings", force: :cascade do |t|
    t.bigint "movie_id", null: false
    t.date "viewed_on", null: false
    t.boolean "rewatch", default: false
    t.text "notes"
    t.string "location"
    t.string "format"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["movie_id", "viewed_on"], name: "index_viewings_on_movie_id_and_viewed_on"
    t.index ["movie_id"], name: "index_viewings_on_movie_id"
    t.index ["viewed_on"], name: "index_viewings_on_viewed_on"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "concert_performances", "concert_artists"
  add_foreign_key "concert_performances", "concerts"
  add_foreign_key "concerts", "concert_venues"
  add_foreign_key "log_entries", "users"
  add_foreign_key "milestones", "bicycles"
  add_foreign_key "movie_posters", "movies"
  add_foreign_key "nba_games", "nba_teams", column: "away_id"
  add_foreign_key "nba_games", "nba_teams", column: "home_id"
  add_foreign_key "rides", "bicycles"
  add_foreign_key "rides", "strava_activities"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "spotify_playlist_tracks", "spotify_playlists"
  add_foreign_key "spotify_playlist_tracks", "spotify_tracks"
  add_foreign_key "spotify_track_artists", "spotify_artists"
  add_foreign_key "spotify_track_artists", "spotify_tracks"
  add_foreign_key "sync_statuses", "users"
  add_foreign_key "viewings", "movies"
end
