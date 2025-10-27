class CreateBicycles < ActiveRecord::Migration[8.0]
  def change
    create_table :bicycles do |t|
      t.string :name, null: false
      t.string :notes
      t.boolean :active, default: true
      t.string :strava_gear_id

      t.timestamps
    end

    add_index :bicycles, :strava_gear_id
    add_index :bicycles, :active
  end
end
