class AddSourceToMoviePosters < ActiveRecord::Migration[7.0]
  def change
    add_column :movie_posters, :source, :string
    add_index :movie_posters, [:movie_id, :url], unique: true
  end
end