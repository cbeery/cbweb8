class CreateSpotifyTracks < ActiveRecord::Migration[8.0]
  def change
    create_table :spotify_tracks do |t|
      t.string :spotify_id, null: false
      t.string :title, null: false
      t.string :artist_text
      t.string :artist_sort_text
      t.string :album
      t.string :album_id
      t.integer :disc_number
      t.integer :track_number
      t.integer :popularity
      t.integer :duration_ms
      t.boolean :explicit, default: false
      t.string :song_url
      t.string :album_url
      t.string :preview_url
      t.string :isrc
      t.jsonb :audio_features, default: {}
      t.jsonb :spotify_data, default: {}

      t.timestamps
    end

    add_index :spotify_tracks, :spotify_id, unique: true
    add_index :spotify_tracks, :artist_sort_text
    add_index :spotify_tracks, :album
    add_index :spotify_tracks, :popularity
  end
end