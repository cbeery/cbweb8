class CreateScrobbleArtists < ActiveRecord::Migration[8.0]
  def change
    create_table :scrobble_artists do |t|
      t.string :name

      t.timestamps
    end
  end
end
