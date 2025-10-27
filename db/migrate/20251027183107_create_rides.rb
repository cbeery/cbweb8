class CreateRides < ActiveRecord::Migration[8.0]
  def change
    create_table :rides do |t|
      t.references :bicycle, null: false, foreign_key: true
      t.references :strava_activity, foreign_key: true  # Optional - can be null for legacy rides
      t.date :rode_on, null: false
      t.decimal :miles, precision: 5, scale: 2
      t.integer :duration  # In seconds
      t.string :notes
      t.bigint :strava_id  # Strava API ID, different from strava_activity_id

      t.timestamps
    end

    add_index :rides, :rode_on
    add_index :rides, :strava_id
    add_index :rides, [:bicycle_id, :rode_on]
  end
end
