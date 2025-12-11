# lib/tasks/letterboxd_compare.rake
require 'csv'

namespace :movies do
  desc "Destroy ALL movies, viewings, and related data (use with caution!)"
  task reset: :environment do
    puts "⚠️  WARNING: This will destroy ALL movie-related data!"
    puts ""
    puts "Current counts:"
    puts "  • Movies: #{Movie.count}"
    puts "  • Viewings: #{Viewing.count}"
    puts "  • Movie Posters: #{MoviePoster.count}"
    puts "  • Theaters: #{Theater.count}"
    puts "  • Film Series: #{FilmSeries.count}"
    puts "  • Film Series Events: #{FilmSeriesEvent.count}"
    puts ""
    
    print "Type 'yes' to confirm destruction: "
    confirmation = $stdin.gets.chomp
    
    unless confirmation.downcase == 'yes'
      puts "Aborted."
      next
    end
    
    puts ""
    puts "Destroying data..."
    
    # Destroy in proper order to avoid FK issues
    # Viewings first (depends on movies, theaters, film_series_events)
    viewing_count = Viewing.count
    Viewing.delete_all
    puts "  ✓ Deleted #{viewing_count} viewings"
    
    # Movie posters (depends on movies)
    poster_count = MoviePoster.count
    MoviePoster.delete_all
    puts "  ✓ Deleted #{poster_count} movie posters"
    
    # Movies
    movie_count = Movie.count
    Movie.delete_all
    puts "  ✓ Deleted #{movie_count} movies"
    
    # Film series events (depends on film_series)
    event_count = FilmSeriesEvent.count
    FilmSeriesEvent.delete_all
    puts "  ✓ Deleted #{event_count} film series events"
    
    # Film series
    series_count = FilmSeries.count
    FilmSeries.delete_all
    puts "  ✓ Deleted #{series_count} film series"
    
    # Theaters (optional - you might want to keep these)
    print "Delete theaters too? (y/n): "
    if $stdin.gets.chomp.downcase == 'y'
      theater_count = Theater.count
      Theater.delete_all
      puts "  ✓ Deleted #{theater_count} theaters"
    else
      puts "  ⏭ Kept #{Theater.count} theaters"
    end
    
    # Reset sequences
    ActiveRecord::Base.connection.reset_pk_sequence!('movies')
    ActiveRecord::Base.connection.reset_pk_sequence!('viewings')
    ActiveRecord::Base.connection.reset_pk_sequence!('movie_posters')
    ActiveRecord::Base.connection.reset_pk_sequence!('film_series_events')
    ActiveRecord::Base.connection.reset_pk_sequence!('film_series')
    
    puts ""
    puts "✅ Movie data reset complete!"
  end

  desc "Quick stats for movies and viewings"
  task stats: :environment do
    puts "📊 Movie Database Stats"
    puts "=" * 40
    puts "Movies: #{Movie.count}"
    puts "  • With ratings: #{Movie.where.not(rating: nil).count}"
    puts "  • With TMDB IDs: #{Movie.where.not(tmdb_id: nil).count}"
    puts "  • With Letterboxd IDs: #{Movie.where.not(letterboxd_id: nil).count}"
    puts ""
    puts "Viewings: #{Viewing.count}"
    puts "  • First watches: #{Viewing.where(rewatch: false).count}"
    puts "  • Rewatches: #{Viewing.where(rewatch: true).count}"
    puts ""
    
    if Viewing.any?
      years = Viewing.group("EXTRACT(YEAR FROM viewed_on)").count.sort
      puts "Viewings by year:"
      years.each do |year, count|
        puts "  #{year.to_i}: #{count}"
      end
    end
  end
end

namespace :letterboxd do
  desc "Compare Rails data with Letterboxd export CSV"
  task :compare, [:file] => :environment do |t, args|
    file_path = args[:file] || find_letterboxd_export
    
    unless file_path && File.exist?(file_path)
      puts "❌ No Letterboxd export file found!"
      puts ""
      puts "Usage: rails letterboxd:compare[path/to/diary.csv]"
      puts ""
      puts "Or place your Letterboxd export files in tmp/letterboxd_import/"
      puts "Expected files from Letterboxd export:"
      puts "  • diary.csv (viewings with dates)"
      puts "  • reviews.csv (reviews)"
      puts "  • ratings.csv (ratings without viewing dates)"
      puts "  • watched.csv (all watched films)"
      next
    end
    
    puts "📊 Comparing Rails data with Letterboxd export..."
    puts "   File: #{file_path}"
    puts ""
    
    compare_with_letterboxd_export(file_path)
  end

  desc "Compare all Letterboxd export files (diary, ratings, watched)"
  task compare_all: :environment do
    import_dir = Rails.root.join('tmp', 'letterboxd_import')
    
    unless Dir.exist?(import_dir)
      puts "❌ Import directory not found: #{import_dir}"
      puts "Create the directory and place your Letterboxd export files there."
      next
    end
    
    puts "📊 Full Letterboxd Export Comparison"
    puts "=" * 50
    puts ""
    
    # Compare diary (viewings)
    diary_file = import_dir.join('diary.csv')
    if File.exist?(diary_file)
      puts "📅 DIARY COMPARISON (Viewings)"
      puts "-" * 40
      compare_diary(diary_file)
      puts ""
    else
      puts "⚠️  diary.csv not found - skipping viewing comparison"
      puts ""
    end
    
    # Compare ratings
    ratings_file = import_dir.join('ratings.csv')
    if File.exist?(ratings_file)
      puts "⭐ RATINGS COMPARISON"
      puts "-" * 40
      compare_ratings(ratings_file)
      puts ""
    else
      puts "⚠️  ratings.csv not found - skipping ratings comparison"
      puts ""
    end
    
    # Compare watched list
    watched_file = import_dir.join('watched.csv')
    if File.exist?(watched_file)
      puts "👁️ WATCHED LIST COMPARISON"
      puts "-" * 40
      compare_watched(watched_file)
      puts ""
    else
      puts "⚠️  watched.csv not found - skipping watched comparison"
      puts ""
    end
    
    # Summary
    puts "=" * 50
    puts "Rails 8 Database Summary:"
    puts "  Movies: #{Movie.count}"
    puts "  Viewings: #{Viewing.count}"
  end

  desc "Verify that Letterboxd sync would not change any data"
  task verify_sync: :environment do
    puts "🔍 Simulating Letterboxd sync (dry run)..."
    puts ""
    
    rss_url = Rails.application.credentials.dig(:letterboxd, :rss_url) || 
              ENV['LETTERBOXD_RSS_URL']
    
    unless rss_url.present?
      puts "❌ No Letterboxd RSS URL configured!"
      puts "Set LETTERBOXD_RSS_URL or add to credentials."
      next
    end
    
    puts "RSS URL: #{rss_url}"
    puts ""
    
    require 'feedjira'
    require 'open-uri'
    require 'nokogiri'
    
    raw_xml = URI.open(rss_url).read
    feed = Feedjira.parse(raw_xml)
    xml_doc = Nokogiri::XML(raw_xml)
    
    would_create = []
    would_update = []
    would_skip = []
    
    feed.entries.each do |entry|
      # Skip non-film entries
      next unless entry.url.include?('/film/')
      next if entry.url.include?('/list/') || entry.url.include?('/journal/')
      
      # Parse entry data
      item_node = xml_doc.xpath("//item[guid[text()='#{entry.entry_id}']]").first
      
      film_title = item_node&.xpath("letterboxd:filmTitle", 'letterboxd' => 'https://letterboxd.com')&.text.presence
      film_year = item_node&.xpath("letterboxd:filmYear", 'letterboxd' => 'https://letterboxd.com')&.text&.to_i
      watched_date = item_node&.xpath("letterboxd:watchedDate", 'letterboxd' => 'https://letterboxd.com')&.text.presence
      member_rating = item_node&.xpath("letterboxd:memberRating", 'letterboxd' => 'https://letterboxd.com')&.text&.to_f
      
      # Fallback parsing from title
      film_title ||= entry.title.match(/^(.+?),\s*\d{4}/)&.[](1) || entry.title.split(' - ').first
      film_year ||= entry.title.match(/,\s*(\d{4})/)&.[](1)&.to_i
      
      next unless watched_date # Skip reviews without viewings
      
      viewed_on = Date.parse(watched_date) rescue nil
      next unless viewed_on
      
      # Check if movie exists
      movie = Movie.find_by(title: film_title, year: film_year)
      
      if movie.nil?
        would_create << { title: film_title, year: film_year, viewed_on: viewed_on }
        next
      end
      
      # Check if viewing exists
      viewing = Viewing.find_by(movie: movie, viewed_on: viewed_on)
      
      if viewing.nil?
        would_create << { title: film_title, year: film_year, viewed_on: viewed_on, movie_exists: true }
      else
        # Check for rating differences
        if member_rating && member_rating > 0 && movie.rating != member_rating
          would_update << { 
            title: film_title, 
            field: 'rating',
            rails_value: movie.rating, 
            letterboxd_value: member_rating 
          }
        else
          would_skip << { title: film_title, viewed_on: viewed_on }
        end
      end
    end
    
    puts "📊 Sync Simulation Results"
    puts "=" * 50
    puts ""
    
    if would_create.empty? && would_update.empty?
      puts "✅ PERFECT SYNC! No changes would be made."
      puts "   #{would_skip.count} entries would be skipped (already in sync)"
    else
      if would_create.any?
        puts "🆕 Would CREATE #{would_create.count} new records:"
        would_create.first(10).each do |item|
          note = item[:movie_exists] ? "(movie exists, new viewing)" : "(new movie + viewing)"
          puts "   • #{item[:title]} (#{item[:year]}) - #{item[:viewed_on]} #{note}"
        end
        puts "   ... and #{would_create.count - 10} more" if would_create.count > 10
        puts ""
      end
      
      if would_update.any?
        puts "📝 Would UPDATE #{would_update.count} records:"
        would_update.first(10).each do |item|
          puts "   • #{item[:title]}: #{item[:field]} #{item[:rails_value]} → #{item[:letterboxd_value]}"
        end
        puts "   ... and #{would_update.count - 10} more" if would_update.count > 10
        puts ""
      end
      
      puts "⏭ Would SKIP #{would_skip.count} entries (already in sync)"
    end
    
    puts ""
    puts "Total RSS entries: #{feed.entries.count}"
  end
end

# Helper methods (private)

def find_letterboxd_export
  import_dir = Rails.root.join('tmp', 'letterboxd_import')
  return nil unless Dir.exist?(import_dir)
  
  # Prefer diary.csv (has viewing dates)
  diary = import_dir.join('diary.csv')
  return diary.to_s if File.exist?(diary)
  
  # Fall back to watched.csv
  watched = import_dir.join('watched.csv')
  return watched.to_s if File.exist?(watched)
  
  nil
end

def compare_with_letterboxd_export(file_path)
  # Detect file type from filename
  filename = File.basename(file_path).downcase
  
  case filename
  when /diary/
    compare_diary(file_path)
  when /ratings/
    compare_ratings(file_path)
  when /watched/
    compare_watched(file_path)
  else
    # Try to auto-detect from headers
    headers = CSV.open(file_path, &:readline)
    if headers.include?('Watched Date')
      compare_diary(file_path)
    elsif headers.include?('Rating')
      compare_ratings(file_path)
    else
      compare_watched(file_path)
    end
  end
end

def compare_diary(file_path)
  letterboxd_viewings = []
  
  CSV.foreach(file_path, headers: true) do |row|
    letterboxd_viewings << {
      title: row['Name'],
      year: row['Year']&.to_i,
      date: parse_date(row['Watched Date']),
      rating: parse_letterboxd_rating(row['Rating']),
      rewatch: row['Rewatch']&.downcase == 'yes'
    }
  end
  
  puts "Letterboxd diary entries: #{letterboxd_viewings.count}"
  puts "Rails viewings: #{Viewing.count}"
  puts ""
  
  # Build lookup from Rails data
  rails_viewings = Viewing.includes(:movie).map do |v|
    {
      title: v.movie.title,
      year: v.movie.year,
      date: v.viewed_on,
      rating: v.movie.rating,
      rewatch: v.rewatch
    }
  end
  
  # Find discrepancies
  only_in_letterboxd = []
  only_in_rails = []
  date_mismatches = []
  rating_mismatches = []
  rewatch_mismatches = []
  
  # Check each Letterboxd entry
  letterboxd_viewings.each do |lb|
    # Find matching Rails viewing (same movie + date)
    rails_match = rails_viewings.find do |r|
      normalize_title(r[:title]) == normalize_title(lb[:title]) &&
        r[:year] == lb[:year] &&
        r[:date] == lb[:date]
    end
    
    if rails_match.nil?
      # Try to find by movie only (date mismatch)
      movie_match = rails_viewings.find do |r|
        normalize_title(r[:title]) == normalize_title(lb[:title]) &&
          r[:year] == lb[:year]
      end
      
      if movie_match
        date_mismatches << {
          title: lb[:title],
          year: lb[:year],
          letterboxd_date: lb[:date],
          rails_date: movie_match[:date]
        }
      else
        only_in_letterboxd << lb
      end
    else
      # Check for rating mismatch
      if lb[:rating] && rails_match[:rating] && lb[:rating] != rails_match[:rating]
        rating_mismatches << {
          title: lb[:title],
          letterboxd_rating: lb[:rating],
          rails_rating: rails_match[:rating]
        }
      end
      
      # Check for rewatch mismatch
      if lb[:rewatch] != rails_match[:rewatch]
        rewatch_mismatches << {
          title: lb[:title],
          letterboxd_rewatch: lb[:rewatch],
          rails_rewatch: rails_match[:rewatch]
        }
      end
    end
  end
  
  # Find Rails viewings not in Letterboxd
  rails_viewings.each do |r|
    lb_match = letterboxd_viewings.find do |lb|
      normalize_title(lb[:title]) == normalize_title(r[:title]) &&
        lb[:year] == r[:year] &&
        lb[:date] == r[:date]
    end
    
    only_in_rails << r if lb_match.nil?
  end
  
  # Report findings
  if only_in_letterboxd.any?
    puts "🔴 Only in Letterboxd (#{only_in_letterboxd.count}):"
    only_in_letterboxd.first(10).each do |v|
      puts "   • #{v[:title]} (#{v[:year]}) - #{v[:date]}"
    end
    puts "   ... and #{only_in_letterboxd.count - 10} more" if only_in_letterboxd.count > 10
    puts ""
  end
  
  if only_in_rails.any?
    puts "🔵 Only in Rails (#{only_in_rails.count}):"
    only_in_rails.first(10).each do |v|
      puts "   • #{v[:title]} (#{v[:year]}) - #{v[:date]}"
    end
    puts "   ... and #{only_in_rails.count - 10} more" if only_in_rails.count > 10
    puts ""
  end
  
  if date_mismatches.any?
    puts "📅 Date mismatches (#{date_mismatches.count}):"
    date_mismatches.first(10).each do |m|
      puts "   • #{m[:title]} (#{m[:year]}): LB=#{m[:letterboxd_date]} vs Rails=#{m[:rails_date]}"
    end
    puts "   ... and #{date_mismatches.count - 10} more" if date_mismatches.count > 10
    puts ""
  end
  
  if rating_mismatches.any?
    puts "⭐ Rating mismatches (#{rating_mismatches.count}):"
    rating_mismatches.first(10).each do |m|
      puts "   • #{m[:title]}: LB=#{m[:letterboxd_rating]} vs Rails=#{m[:rails_rating]}"
    end
    puts "   ... and #{rating_mismatches.count - 10} more" if rating_mismatches.count > 10
    puts ""
  end
  
  if rewatch_mismatches.any?
    puts "🔄 Rewatch flag mismatches (#{rewatch_mismatches.count}):"
    rewatch_mismatches.first(10).each do |m|
      puts "   • #{m[:title]}: LB=#{m[:letterboxd_rewatch]} vs Rails=#{m[:rails_rewatch]}"
    end
    puts "   ... and #{rewatch_mismatches.count - 10} more" if rewatch_mismatches.count > 10
    puts ""
  end
  
  total_issues = only_in_letterboxd.count + only_in_rails.count + 
                 date_mismatches.count + rating_mismatches.count + rewatch_mismatches.count
  
  if total_issues == 0
    puts "✅ PERFECT MATCH! All viewings are in sync."
  else
    puts "⚠️  Total discrepancies: #{total_issues}"
  end
end

def compare_ratings(file_path)
  letterboxd_ratings = {}
  
  CSV.foreach(file_path, headers: true) do |row|
    key = "#{normalize_title(row['Name'])}|#{row['Year']}"
    letterboxd_ratings[key] = parse_letterboxd_rating(row['Rating'])
  end
  
  puts "Letterboxd rated movies: #{letterboxd_ratings.count}"
  puts "Rails movies with ratings: #{Movie.where.not(rating: nil).count}"
  puts ""
  
  mismatches = []
  only_in_letterboxd = []
  only_in_rails = []
  
  # Check Letterboxd ratings against Rails
  letterboxd_ratings.each do |key, lb_rating|
    title, year = key.split('|')
    year = year.to_i
    
    movie = Movie.find_by("LOWER(title) = ? AND year = ?", title.downcase, year)
    
    if movie.nil?
      only_in_letterboxd << { title: title, year: year, rating: lb_rating }
    elsif movie.rating != lb_rating
      mismatches << { 
        title: title, 
        year: year,
        letterboxd: lb_rating, 
        rails: movie.rating 
      }
    end
  end
  
  # Check Rails ratings not in Letterboxd
  Movie.where.not(rating: nil).find_each do |movie|
    key = "#{normalize_title(movie.title)}|#{movie.year}"
    unless letterboxd_ratings.key?(key)
      only_in_rails << { title: movie.title, year: movie.year, rating: movie.rating }
    end
  end
  
  if mismatches.any?
    puts "⭐ Rating mismatches (#{mismatches.count}):"
    mismatches.first(10).each do |m|
      puts "   • #{m[:title]} (#{m[:year]}): LB=#{m[:letterboxd]} vs Rails=#{m[:rails]}"
    end
    puts ""
  end
  
  if only_in_letterboxd.any?
    puts "🔴 Rated only in Letterboxd (#{only_in_letterboxd.count}):"
    only_in_letterboxd.first(5).each do |m|
      puts "   • #{m[:title]} (#{m[:year]}): #{m[:rating]}"
    end
    puts ""
  end
  
  if only_in_rails.any?
    puts "🔵 Rated only in Rails (#{only_in_rails.count}):"
    only_in_rails.first(5).each do |m|
      puts "   • #{m[:title]} (#{m[:year]}): #{m[:rating]}"
    end
    puts ""
  end
  
  total_issues = mismatches.count + only_in_letterboxd.count + only_in_rails.count
  if total_issues == 0
    puts "✅ All ratings match!"
  else
    puts "⚠️  Total rating discrepancies: #{total_issues}"
  end
end

def compare_watched(file_path)
  letterboxd_watched = Set.new
  
  CSV.foreach(file_path, headers: true) do |row|
    letterboxd_watched << "#{normalize_title(row['Name'])}|#{row['Year']}"
  end
  
  rails_watched = Set.new
  Movie.joins(:viewings).distinct.find_each do |movie|
    rails_watched << "#{normalize_title(movie.title)}|#{movie.year}"
  end
  
  puts "Letterboxd watched: #{letterboxd_watched.count}"
  puts "Rails watched: #{rails_watched.count}"
  puts ""
  
  only_in_letterboxd = letterboxd_watched - rails_watched
  only_in_rails = rails_watched - letterboxd_watched
  
  if only_in_letterboxd.any?
    puts "🔴 Only in Letterboxd (#{only_in_letterboxd.count}):"
    only_in_letterboxd.first(10).each do |key|
      title, year = key.split('|')
      puts "   • #{title} (#{year})"
    end
    puts "   ... and #{only_in_letterboxd.count - 10} more" if only_in_letterboxd.count > 10
    puts ""
  end
  
  if only_in_rails.any?
    puts "🔵 Only in Rails (#{only_in_rails.count}):"
    only_in_rails.first(10).each do |key|
      title, year = key.split('|')
      puts "   • #{title} (#{year})"
    end
    puts "   ... and #{only_in_rails.count - 10} more" if only_in_rails.count > 10
    puts ""
  end
  
  if only_in_letterboxd.empty? && only_in_rails.empty?
    puts "✅ Watched lists match perfectly!"
  end
end

def normalize_title(title)
  return '' if title.nil?
  title.downcase.gsub(/[^\w\s]/, '').gsub(/\s+/, ' ').strip
end

def parse_date(date_str)
  return nil if date_str.blank?
  Date.parse(date_str) rescue nil
end

def parse_letterboxd_rating(rating_str)
  return nil if rating_str.blank?
  
  # Letterboxd exports ratings as star counts (0.5 to 5.0)
  rating = rating_str.to_f
  return nil if rating <= 0
  
  # Ensure it's in valid range
  [[rating, 0.5].max, 5.0].min
end
