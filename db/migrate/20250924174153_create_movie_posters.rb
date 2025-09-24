class CreateMoviePosters < ActiveRecord::Migration[7.0]
  def change
    create_table :movie_posters do |t|
      t.references :movie, null: false, foreign_key: true
      t.text :url
      t.boolean :primary, default: false
      t.integer :position
      
      t.timestamps
    end
    
    add_index :movie_posters, [:movie_id, :primary]
    add_index :movie_posters, :position
  end
end