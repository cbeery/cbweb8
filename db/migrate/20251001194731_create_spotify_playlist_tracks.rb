class CreateSpotifyPlaylistTracks < ActiveRecord::Migration[8.0]
  def change
    create_table :spotify_playlist_tracks do |t|
      t.references :spotify_playlist, null: false, foreign_key: true
      t.references :spotify_track, null: false, foreign_key: true
      t.integer :position, null: false
      t.datetime :added_at
      t.string :added_by

      t.timestamps
    end

    add_index :spotify_playlist_tracks, [:spotify_playlist_id, :position]
    add_index :spotify_playlist_tracks, 
              [:spotify_playlist_id, :spotify_track_id], 
              unique: true, 
              name: 'index_playlist_tracks_unique'
  end
end