class CreateConcertVenues < ActiveRecord::Migration[8.0]
  def change
    create_table :concert_venues do |t|
      t.string :name, null: false
      t.string :city
      t.string :state

      t.timestamps
    end
    
    add_index :concert_venues, :name
    add_index :concert_venues, [:city, :state]
  end
end
