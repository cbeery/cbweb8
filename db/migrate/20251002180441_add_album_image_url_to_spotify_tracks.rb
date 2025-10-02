class AddAlbumImageUrlToSpotifyTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :spotify_tracks, :album_image_url, :string
    add_index :spotify_tracks, :album_image_url
  end
end