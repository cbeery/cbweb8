class CreateScrobblePlays < ActiveRecord::Migration[8.0]
  def change
    create_table :scrobble_plays do |t|
      t.bigint :scrobble_artist_id
      t.bigint :scrobble_album_id
      t.integer :plays
      t.date :played_on
      t.string :category

      t.timestamps
    end
  end
end
