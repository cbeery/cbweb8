class CreateScrobbleAlbums < ActiveRecord::Migration[8.0]
  def change
    create_table :scrobble_albums do |t|
      t.string :name
      t.bigint :scrobble_artist_id

      t.timestamps
    end
  end
end
