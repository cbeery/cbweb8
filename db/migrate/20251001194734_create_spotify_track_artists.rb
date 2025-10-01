class CreateSpotifyTrackArtists < ActiveRecord::Migration[8.0]
  def change
    create_table :spotify_track_artists do |t|
      t.references :spotify_track, null: false, foreign_key: true
      t.references :spotify_artist, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :spotify_track_artists, 
              [:spotify_track_id, :spotify_artist_id], 
              unique: true, 
              name: 'index_track_artists_unique'
  end
end