class CreateTopScrobbleImages < ActiveRecord::Migration[8.0]
  def change
    create_table :top_scrobble_images do |t|
      t.string :category, null: false  # artist, album, track
      t.string :artist, null: false
      t.string :name                   # null for artists
      t.text :image_url
      t.string :spotify_id             # for reference/debugging
      t.string :status, null: false, default: 'pending'  # pending, found, not_found

      t.timestamps
    end

    add_index :top_scrobble_images, [:category, :artist, :name], unique: true, name: 'idx_top_scrobble_images_lookup'
    add_index :top_scrobble_images, :status
  end
end
