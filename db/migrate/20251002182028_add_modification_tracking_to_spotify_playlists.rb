class AddModificationTrackingToSpotifyPlaylists < ActiveRecord::Migration[8.0]
  def change
    add_column :spotify_playlists, :last_modified_at, :datetime
    add_column :spotify_playlists, :previous_snapshot_id, :string
    
    add_index :spotify_playlists, :last_modified_at
    add_index :spotify_playlists, :previous_snapshot_id
  end
end