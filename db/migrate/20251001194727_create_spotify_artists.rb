class CreateSpotifyArtists < ActiveRecord::Migration[8.0]
  def change
    create_table :spotify_artists do |t|
      t.string :spotify_id, null: false
      t.string :name, null: false
      t.string :sort_name
      t.string :spotify_url
      t.integer :followers_count
      t.integer :popularity
      t.string :image_url
      t.jsonb :genres, default: []
      t.jsonb :spotify_data, default: {}

      t.timestamps
    end

    add_index :spotify_artists, :spotify_id, unique: true
    add_index :spotify_artists, :name
    add_index :spotify_artists, :sort_name
  end
end