# lib/tasks/letterboxd_export.rake
require 'csv'

namespace :letterboxd do
  desc "Export movies and viewings to Letterboxd CSV format"
  task export: :environment do
    export_all
  end
  
  desc "Export only movies (without viewing dates) to Letterboxd CSV format"
  task export_movies: :environment do
    export_movies_only
  end
  
  desc "Export only viewings to Letterboxd CSV format"
  task export_viewings: :environment do
    export_viewings_only
  end
  
  desc "Export movies from a specific year to Letterboxd CSV format"
  task :export_year, [:year] => :environment do |t, args|
    year = args[:year].to_i
    abort "Please provide a valid year" if year == 0
    export_by_year(year)
  end
  
  private
  
  def export_all
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = Rails.root.join('tmp', "letterboxd_export_#{timestamp}.csv")
    
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    
    row_count = 0
    
    CSV.open(filename, 'w', encoding: 'UTF-8') do |csv|
      # Letterboxd required headers
      csv << ['Title', 'Year', 'Directors', 'tmdbID', 'Rating', 'WatchedDate', 'Rewatch', 'Tags', 'Review', 'LetterboxdURI']
      
      # Export all viewings
      Viewing.includes(movie: :movie_posters).find_each do |viewing|
        movie = viewing.movie
        
        csv << [
          movie.title,
          movie.year,
          movie.director,
          movie.tmdb_id,
          format_rating(movie.rating),
          viewing.viewed_on.strftime('%Y-%m-%d'),
          viewing.rewatch ? 'true' : 'false',
          format_tags(viewing),
          clean_review(viewing.notes),
          movie.letterboxd_id ? "https://letterboxd.com/film/#{movie.letterboxd_id}" : nil
        ]
        
        row_count += 1
      end
      
      # Also export movies without viewings but with ratings
      Movie.left_joins(:viewings).where(viewings: { id: nil }).where.not(rating: nil).find_each do |movie|
        csv << [
          movie.title,
          movie.year,
          movie.director,
          movie.tmdb_id,
          format_rating(movie.rating),
          nil, # No watched date
          nil, # No rewatch flag
          nil, # No tags (no viewing)
          clean_review(movie.review), # Use movie's review if available
          movie.letterboxd_id ? "https://letterboxd.com/film/#{movie.letterboxd_id}" : nil
        ]
        
        row_count += 1
      end
    end
    
    puts "✅ Export completed successfully!"
    puts "📁 File saved to: #{filename}"
    puts "📊 Total entries exported: #{row_count}"
    puts ""
    puts "You can now import this file to Letterboxd at:"
    puts "https://letterboxd.com/import/"
  end
  
  def export_movies_only
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = Rails.root.join('tmp', "letterboxd_movies_#{timestamp}.csv")
    
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    
    row_count = 0
    
    CSV.open(filename, 'w', encoding: 'UTF-8') do |csv|
      csv << ['Title', 'Year', 'Directors', 'tmdbID', 'Rating', 'Review', 'LetterboxdURI']
      
      Movie.find_each do |movie|
        csv << [
          movie.title,
          movie.year,
          movie.director,
          movie.tmdb_id,
          format_rating(movie.rating),
          clean_review(movie.review),
          movie.letterboxd_id ? "https://letterboxd.com/film/#{movie.letterboxd_id}" : nil
        ]
        
        row_count += 1
      end
    end
    
    puts "✅ Movies export completed!"
    puts "📁 File saved to: #{filename}"
    puts "📊 Total movies exported: #{row_count}"
  end
  
  def export_viewings_only
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = Rails.root.join('tmp', "letterboxd_viewings_#{timestamp}.csv")
    
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    
    row_count = 0
    
    CSV.open(filename, 'w', encoding: 'UTF-8') do |csv|
      csv << ['Title', 'Year', 'Directors', 'tmdbID', 'Rating', 'WatchedDate', 'Rewatch', 'Tags', 'Review', 'LetterboxdURI']
      
      Viewing.includes(:movie).order(viewed_on: :desc).find_each do |viewing|
        movie = viewing.movie
        
        csv << [
          movie.title,
          movie.year,
          movie.director,
          movie.tmdb_id,
          format_rating(movie.rating),
          viewing.viewed_on.strftime('%Y-%m-%d'),
          viewing.rewatch ? 'true' : 'false',
          format_tags(viewing),
          clean_review(viewing.notes),
          movie.letterboxd_id ? "https://letterboxd.com/film/#{movie.letterboxd_id}" : nil
        ]
        
        row_count += 1
      end
    end
    
    puts "✅ Viewings export completed!"
    puts "📁 File saved to: #{filename}"
    puts "📊 Total viewings exported: #{row_count}"
  end
  
  def export_by_year(year)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = Rails.root.join('tmp', "letterboxd_#{year}_#{timestamp}.csv")
    
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    
    row_count = 0
    start_date = Date.new(year, 1, 1)
    end_date = Date.new(year, 12, 31)
    
    CSV.open(filename, 'w', encoding: 'UTF-8') do |csv|
      csv << ['Title', 'Year', 'Directors', 'tmdbID', 'Rating', 'WatchedDate', 'Rewatch', 'Tags', 'Review', 'LetterboxdURI']
      
      Viewing.includes(:movie)
             .where(viewed_on: start_date..end_date)
             .order(viewed_on: :asc)
             .find_each do |viewing|
        movie = viewing.movie
        
        csv << [
          movie.title,
          movie.year,
          movie.director,
          movie.tmdb_id,
          format_rating(movie.rating),
          viewing.viewed_on.strftime('%Y-%m-%d'),
          viewing.rewatch ? 'true' : 'false',
          format_tags(viewing),
          clean_review(viewing.notes),
          movie.letterboxd_id ? "https://letterboxd.com/film/#{movie.letterboxd_id}" : nil
        ]
        
        row_count += 1
      end
    end
    
    puts "✅ Export for year #{year} completed!"
    puts "📁 File saved to: #{filename}"
    puts "📊 Total viewings exported: #{row_count}"
  end
  
  # Helper methods
  
  def format_rating(rating)
    return nil if rating.nil?
    
    # Letterboxd accepts ratings from 0.5 to 5.0 in 0.5 increments
    # Ensure rating is within bounds and properly formatted
    rating = [[rating.to_f, 0.5].max, 5.0].min
    
    # Round to nearest 0.5
    (rating * 2).round / 2.0
  end
  
  def format_tags(viewing)
    return nil unless viewing.location.present?
    
    # Only include theater or home as tags
    case viewing.location
    when 'theater'
      'theater'
    when 'home'
      'home'
    end
  end
  
  def clean_review(text)
    return nil if text.blank?
    
    # Letterboxd accepts HTML but we should clean up the text
    # Remove any problematic characters and ensure proper encoding
    text = text.strip
    
    # Escape quotes for CSV
    text = text.gsub('"', '\"')
    
    # Ensure the text doesn't break CSV format
    # Wrap in quotes if it contains commas or newlines
    if text.include?(',') || text.include?("\n")
      "\"#{text}\""
    else
      text
    end
  end
end

namespace :letterboxd do
  desc "Validate export data before creating CSV"
  task validate: :environment do
    puts "🔍 Validating movie data for Letterboxd export..."
    puts ""
    
    issues = []
    
    # Check for movies without titles
    movies_without_titles = Movie.where(title: [nil, ''])
    if movies_without_titles.any?
      issues << "#{movies_without_titles.count} movies without titles"
    end
    
    # Check for invalid ratings
    invalid_ratings = Movie.where.not(rating: nil).where.not(rating: 0.5..5.0)
    if invalid_ratings.any?
      issues << "#{invalid_ratings.count} movies with invalid ratings (must be 0.5-5.0)"
    end
    
    # Check for viewings without dates
    viewings_without_dates = Viewing.where(viewed_on: nil)
    if viewings_without_dates.any?
      issues << "#{viewings_without_dates.count} viewings without dates"
    end
    
    # Check for orphaned viewings
    orphaned_viewings = Viewing.left_joins(:movie).where(movies: { id: nil })
    if orphaned_viewings.any?
      issues << "#{orphaned_viewings.count} viewings without associated movies"
    end
    
    # Summary statistics
    puts "📊 Export Statistics:"
    puts "  • Total movies: #{Movie.count}"
    puts "  • Movies with ratings: #{Movie.where.not(rating: nil).count}"
    puts "  • Movies with TMDB IDs: #{Movie.where.not(tmdb_id: nil).count}"
    puts "  • Movies with Letterboxd IDs: #{Movie.where.not(letterboxd_id: nil).count}"
    puts "  • Total viewings: #{Viewing.count}"
    puts "  • Rewatches: #{Viewing.where(rewatch: true).count}"
    puts "  • Theater viewings: #{Viewing.where(location: 'theater').count}"
    puts "  • Home viewings: #{Viewing.where(location: 'home').count}"
    puts ""
    
    if issues.any?
      puts "⚠️  Issues found:"
      issues.each { |issue| puts "  • #{issue}" }
      puts ""
      puts "Consider fixing these issues before exporting."
    else
      puts "✅ All data looks good for export!"
    end
  end
  
  desc "Preview first 10 entries of export"
  task preview: :environment do
    puts "👀 Preview of Letterboxd export (first 10 entries):"
    puts ""
    
    headers = ['Title', 'Year', 'Directors', 'TMDB ID', 'Rating', 'Watched', 'Rewatch', 'Tags', 'Has Notes']
    
    rows = []
    Viewing.includes(:movie).limit(10).each do |viewing|
      movie = viewing.movie
      tag = case viewing.location
            when 'theater' then 'theater'
            when 'home' then 'home'
            else '-'
            end
      
      rows << [
        movie.title[0..30],
        movie.year,
        movie.director ? movie.director[0..20] : '-',
        movie.tmdb_id || '-',
        movie.rating || '-',
        viewing.viewed_on.strftime('%Y-%m-%d'),
        viewing.rewatch? ? '✓' : '-',
        tag,
        viewing.notes.present? ? '✓' : '-'
      ]
    end
    
    # Simple table output
    col_widths = headers.each_with_index.map do |header, i|
      [header.length, rows.map { |r| r[i].to_s.length }.max || 0].max + 2
    end
    
    # Print headers
    headers.each_with_index do |header, i|
      print header.ljust(col_widths[i])
    end
    puts
    puts "-" * col_widths.sum
    
    # Print rows
    rows.each do |row|
      row.each_with_index do |cell, i|
        print cell.to_s.ljust(col_widths[i])
      end
      puts
    end
    
    puts ""
    puts "Run 'rails letterboxd:export' to generate the full CSV file."
  end
end
