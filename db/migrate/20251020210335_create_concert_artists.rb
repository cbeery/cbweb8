class CreateConcertArtists < ActiveRecord::Migration[8.0]
  def change
    create_table :concert_artists do |t|
      t.string :name, null: false

      t.timestamps
    end
    
    add_index :concert_artists, :name, unique: true
  end
end