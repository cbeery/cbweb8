# app/helpers/legacy_helper.rb
module LegacyHelper
  # Safe route helpers that check if routes exist
  
  def safe_admin_movie_path(movie)
    admin_movie_path(movie) rescue "#"
  end
  
  def safe_admin_movies_path
    admin_movies_path rescue "#"
  end
  
  def safe_admin_book_path(book)
    admin_book_path(book) rescue "#"
  end
  
  def safe_admin_books_path
    admin_books_path rescue "#"
  end
  
  def safe_admin_lastfm_path
    admin_lastfm_top_path rescue "#"
  end
  
  # Check if a model exists
  def model_exists?(model_name)
    Object.const_defined?(model_name)
  end
  
  # Safe way to check if a column exists
  def column_exists?(model, column)
    model_exists?(model.to_s) && model.to_s.constantize.column_names.include?(column.to_s)
  end
end
