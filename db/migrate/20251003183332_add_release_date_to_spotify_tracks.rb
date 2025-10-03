# db/migrate/[timestamp]_add_release_date_to_spotify_tracks.rb
class AddReleaseDateToSpotifyTracks < ActiveRecord::Migration[7.0]
  def change
    add_column :spotify_tracks, :release_date, :date
    add_column :spotify_tracks, :release_date_precision, :string # Can be 'day', 'month', or 'year'
    add_column :spotify_tracks, :release_year, :integer
    
    add_index :spotify_tracks, :release_date
    add_index :spotify_tracks, :release_year
  end
end