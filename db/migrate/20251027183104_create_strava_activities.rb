class CreateStravaActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_activities do |t|
      t.string :name
      t.bigint :strava_id, null: false
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :moving_time
      t.integer :elapsed_time
      t.decimal :distance, precision: 7, scale: 1
      t.decimal :distance_in_miles, precision: 5, scale: 2
      t.string :activity_type
      t.boolean :commute, default: false
      t.string :gear_id
      t.string :city
      t.string :state
      t.boolean :private, default: false

      t.timestamps
    end

    add_index :strava_activities, :strava_id, unique: true
    add_index :strava_activities, :started_at
    add_index :strava_activities, :activity_type
    add_index :strava_activities, :gear_id
    add_index :strava_activities, :commute
  end
end
