class CreateMovies < ActiveRecord::Migration[7.0]
  def change
    create_table :movies do |t|
      t.string :title, null: false
      t.string :director
      t.integer :year
      t.decimal :rating, precision: 2, scale: 1 # 0.5 to 5.0
      t.decimal :score, precision: 5, scale: 2  # 0.00 to 100.00 (legacy)
      t.string :letterboxd_id
      t.string :tmdb_id
      t.datetime :last_synced_at
      t.text :review
      t.text :url
      
      t.timestamps
    end
    
    add_index :movies, :letterboxd_id, unique: true
    add_index :movies, :tmdb_id
    add_index :movies, :title
    add_index :movies, :year
  end
end
