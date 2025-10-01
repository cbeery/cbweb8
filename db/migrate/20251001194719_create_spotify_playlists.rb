class CreateSpotifyPlaylists < ActiveRecord::Migration[8.0]
  def change
    create_table :spotify_playlists do |t|
      t.string :name, null: false
      t.string :spotify_url, null: false
      t.string :spotify_id
      t.string :made_by
      t.boolean :mixtape, default: false
      t.date :made_on
      t.integer :year
      t.integer :month
      t.integer :runtime_ms, default: 0
      t.string :owner_name
      t.string :owner_id
      t.text :description
      t.boolean :public
      t.boolean :collaborative, default: false
      t.integer :followers_count, default: 0
      t.string :image_url
      t.string :snapshot_id
      t.jsonb :spotify_data, default: {}
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :spotify_playlists, :spotify_url
    add_index :spotify_playlists, :spotify_id, unique: true
    add_index :spotify_playlists, :mixtape
    add_index :spotify_playlists, [:year, :month]
    add_index :spotify_playlists, :made_on
  end
end
