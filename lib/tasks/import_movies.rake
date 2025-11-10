# lib/tasks/import_movies.rake
namespace :import do
  desc "Import all movie-related data from CSV files"
  task movies_full: :environment do
    puts "Starting full movie data import..."
    puts "=" * 50
    
    # Import in proper order to maintain foreign key relationships
    Rake::Task["import:movies"].invoke
    Rake::Task["import:theaters"].invoke
    Rake::Task["import:film_series"].invoke
    Rake::Task["import:film_series_events"].invoke
    Rake::Task["import:viewings"].invoke
    Rake::Task["import:fetch_movie_posters"].invoke
    
    puts "=" * 50
    puts "Full movie data import completed!"
    puts "Movies: #{Movie.count}"
    puts "Theaters: #{Theater.count}"
    puts "Film Series: #{FilmSeries.count}"
    puts "Film Series Events: #{FilmSeriesEvent.count}"
    puts "Viewings: #{Viewing.count}"
    puts "Movie Posters: #{MoviePoster.count}"
  end
  
  desc "Import movies from CSV"
  task movies: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'movies.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing movies..."
    success_count = 0
    error_count = 0
    tmdb_count = 0
    
    movies_to_insert = []
    movies_to_update = []
    
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        # Extract TMDB ID from URL if present
        tmdb_id = extract_tmdb_id(row['url']) if row['url'].present?
        tmdb_count += 1 if tmdb_id.present?
        
        # Convert score to rating (assuming score is 0-100, rating is 0.5-5.0)
        rating = calculate_rating_from_score(row['score']&.to_f)
        
        movie_attrs = {
          id: row['id'].to_i,
          title: row['title'],
          director: row['director'],
          year: row['year']&.to_i,
          url: row['url'],
          score: row['score']&.to_f,
          rating: rating,
          tmdb_id: tmdb_id,
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        }
        
        # Check if movie exists
        if Movie.exists?(id: movie_attrs[:id])
          movies_to_update << movie_attrs
        else
          movies_to_insert << movie_attrs
        end
        
      rescue => e
        error_count += 1
        puts "\nError processing movie row #{row['id']}: #{e.message}"
      end
    end
    
    # Bulk insert new movies
    if movies_to_insert.any?
      Movie.insert_all(movies_to_insert)
      puts "✓ Inserted #{movies_to_insert.size} new movies"
    end
    
    # Update existing movies
    movies_to_update.each do |attrs|
      Movie.find(attrs[:id]).update!(attrs.except(:id))
      print '.'
    end
    
    if movies_to_update.any?
      puts "\n✓ Updated #{movies_to_update.size} existing movies"
    end
    
    puts "Movies import completed: #{movies_to_insert.size + movies_to_update.size} successful, #{error_count} errors"
    puts "  Found #{tmdb_count} TMDB IDs"
    
    # Reset sequence to ensure new records don't conflict
    ActiveRecord::Base.connection.reset_pk_sequence!('movies')
  end
  
  desc "Import theaters from CSV"
  task theaters: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'theaters.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing theaters..."
    theaters_to_insert = []
    
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        theaters_to_insert << {
          id: row['id'].to_i,
          name: row['name'],
          city: row['city'],
          state: row['state'],
          description: row['description'],
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        }
      rescue => e
        puts "Error processing theater row #{row['id']}: #{e.message}"
      end
    end
    
    if theaters_to_insert.any?
      # Use upsert to handle existing records
      Theater.upsert_all(theaters_to_insert, unique_by: :id)
      puts "✓ Imported #{theaters_to_insert.size} theaters"
    end
    
    ActiveRecord::Base.connection.reset_pk_sequence!('theaters')
  end
  
  desc "Import film series from CSV"
  task film_series: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'film_series.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing film series..."
    series_to_insert = []
    
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        series_to_insert << {
          id: row['id'].to_i,
          name: row['name'],
          description: row['description'],
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        }
      rescue => e
        puts "Error processing film series row #{row['id']}: #{e.message}"
      end
    end
    
    if series_to_insert.any?
      FilmSeries.upsert_all(series_to_insert, unique_by: :id)
      puts "✓ Imported #{series_to_insert.size} film series"
    end
    
    ActiveRecord::Base.connection.reset_pk_sequence!('film_series')
  end
  
  desc "Import film series events from CSV"
  task film_series_events: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'film_series_events.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing film series events..."
    events_to_insert = []
    
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        events_to_insert << {
          id: row['id'].to_i,
          name: row['name'],
          film_series_id: row['film_series_id']&.to_i,
          started_on: parse_date(row['started_on']),
          ended_on: parse_date(row['ended_on']),
          notes: row['notes'],
          # url field exists in model but you said to ignore for now
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        }
      rescue => e
        puts "Error processing film series event row #{row['id']}: #{e.message}"
      end
    end
    
    if events_to_insert.any?
      FilmSeriesEvent.upsert_all(events_to_insert, unique_by: :id)
      puts "✓ Imported #{events_to_insert.size} film series events"
    end
    
    ActiveRecord::Base.connection.reset_pk_sequence!('film_series_events')
  end
  
  desc "Import viewings from CSV"
  task viewings: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'viewings.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing viewings..."
    success_count = 0
    error_count = 0
    skipped_count = 0
    home_count = 0
    theater_count = 0
    
    # Track first viewing of each movie (for rewatch detection)
    # Since CSV is chronological (oldest first), first occurrence = first viewing
    first_viewings = {}
    
    # Process viewings one by one to avoid upsert_all key mismatch issues
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        # Skip if no movie_id (viewable_id in legacy data)
        movie_id = row['viewable_id'] || row['movie_id']
        if movie_id.blank?
          skipped_count += 1
          next
        end
        
        movie_id = movie_id.to_i
        
        # Skip if movie doesn't exist
        unless Movie.exists?(id: movie_id)
          puts "  ⚠ Skipping viewing - Movie ##{movie_id} not found"
          skipped_count += 1
          next
        end
        
        # Convert home boolean to location
        location = nil
        if row['home'].present?
          is_home = row['home'].to_s.downcase == 'true' || row['home'] == '1'
          location = is_home ? 'home' : 'theater'
          is_home ? home_count += 1 : theater_count += 1
        elsif row['location'].present?
          location = row['location']
        end
        
        # Parse datetime for viewed_at
        viewed_at = nil
        if row['viewed_at'].present?
          viewed_at = DateTime.parse(row['viewed_at']) rescue nil
        end
        
        # Parse date for viewed_on (fallback from viewed_at if needed)
        viewed_on = parse_date(row['viewed_on'])
        if viewed_on.nil? && viewed_at
          viewed_on = viewed_at.to_date
        end
        
        # Skip if no valid date
        if viewed_on.nil?
          puts "  ⚠ Skipping viewing - No valid date for movie ##{movie_id}"
          skipped_count += 1
          next
        end
        
        # Determine if this is a rewatch
        # Since CSV is chronological (oldest first), if we've seen this movie_id before, it's a rewatch
        is_rewatch = if row['rewatch'].present?
          # Use explicit rewatch value if provided
          row['rewatch'].to_s.downcase == 'true'
        else
          # Otherwise, check if we've seen this movie before
          if first_viewings.key?(movie_id)
            true  # We've seen this movie before, so it's a rewatch
          else
            first_viewings[movie_id] = viewed_on  # Mark this as the first viewing
            false  # This is the first viewing
          end
        end
        
        # Build viewing - use find_or_initialize_by if ID is present
        viewing = if row['id'].present?
          Viewing.find_or_initialize_by(id: row['id'].to_i)
        else
          Viewing.new
        end
        
        # Assign attributes
        viewing.assign_attributes(
          movie_id: movie_id,
          viewed_on: viewed_on,
          viewed_at: viewed_at,
          theater_id: row['theater_id'].presence&.to_i,
          film_series_event_id: row['film_series_event_id'].presence&.to_i,
          location: location,
          price: row['price'].presence&.to_f,
          notes: row['notes'].presence,
          rewatch: is_rewatch,
          format: row['format'].presence,
          time: row['time'].presence
        )
        
        # Set timestamps if creating new record
        if viewing.new_record?
          viewing.created_at = row['created_at'].presence || Time.current
          viewing.updated_at = row['updated_at'].presence || Time.current
        end
        
        # Save with validation (but skip the auto rewatch detection callback)
        if viewing.save(validate: false)
          success_count += 1
          print is_rewatch ? 'R' : '.'
        else
          # Try again with validation to get error messages
          viewing.save
          error_count += 1
          puts "\n  ✗ Failed to save viewing: #{viewing.errors.full_messages.join(', ')}"
          puts "    Movie: #{movie_id}, Date: #{viewed_on}"
        end
        
      rescue => e
        error_count += 1
        puts "\n  ✗ Error processing viewing row: #{e.message}"
        puts "    Data: #{row.to_h.compact.inspect}"
      end
    end
    
    puts "\nViewings import completed:"
    puts "  ✓ #{success_count} successful"
    puts "  ⚠ #{skipped_count} skipped"
    puts "  ✗ #{error_count} errors"
    puts "  📍 #{home_count} home viewings, #{theater_count} theater viewings"
    puts "  🔄 #{first_viewings.size} unique movies watched"
    
    ActiveRecord::Base.connection.reset_pk_sequence!('viewings')
  end
  
  desc "Fetch movie posters from TMDB for movies with tmdb_id"
  task fetch_movie_posters: :environment do
    movies_with_tmdb = Movie.where.not(tmdb_id: nil)
                            .left_joins(:movie_posters)
                            .where(movie_posters: { id: nil })
                            .limit(100) # Rate limit protection
    
    if movies_with_tmdb.empty?
      puts "No movies need poster fetching"
      next
    end
    
    puts "Fetching posters for #{movies_with_tmdb.count} movies from TMDB..."
    success_count = 0
    error_count = 0
    
    movies_with_tmdb.find_each do |movie|
      begin
        # Get poster from TMDB
        tmdb_movie = TmdbService.get_movie(movie.tmdb_id)
        
        if tmdb_movie && tmdb_movie['poster_path'].present?
          poster_url = TmdbService.poster_url(tmdb_movie['poster_path'], size: 'original')
          
          poster = movie.movie_posters.create!(
            url: poster_url,
            source: 'tmdb',
            primary: true,
            position: 1
          )
          
          # Queue download job
          DownloadPosterJob.perform_later(poster)
          
          success_count += 1
          print '.'
        else
          print 'x'
        end
        
        # Rate limit protection
        sleep 0.25
        
      rescue => e
        error_count += 1
        puts "\n  ✗ Error fetching poster for '#{movie.title}': #{e.message}"
      end
    end
    
    puts "\n✓ Poster fetch completed: #{success_count} successful, #{error_count} errors"
  end
  
  # Helper methods
  
  def self.extract_tmdb_id(url)
    return nil if url.blank?
    
    # Match patterns like:
    # https://www.themoviedb.org/movie/550-fight-club
    # https://www.themoviedb.org/movie/550
    # https://themoviedb.org/movie/550-fight-club
    
    if url.include?('themoviedb.org') || url.include?('tmdb.org')
      match = url.match(/movie\/(\d+)/)
      return match[1] if match
    end
    
    nil
  end
  
  def self.calculate_rating_from_score(score)
    return nil if score.nil? || score == 0
    
    # Convert 0-100 score to 0.5-5.0 rating
    # Using a linear scale: score/20 gives 0-5, but we want 0.5-5.0
    # So: (score/100 * 4.5) + 0.5
    rating = (score / 100.0 * 4.5) + 0.5
    
    # Round to nearest 0.5
    (rating * 2).round / 2.0
  end
  
  def self.parse_date(date_string)
    return nil if date_string.blank?
    
    Date.parse(date_string)
  rescue ArgumentError
    # Try common date formats
    formats = ['%m/%d/%Y', '%Y-%m-%d', '%d/%m/%Y', '%Y/%m/%d']
    
    formats.each do |format|
      begin
        return Date.strptime(date_string, format)
      rescue ArgumentError
        next
      end
    end
    
    nil
  end
end

# Additional utility tasks
namespace :movies do
  desc "Generate sample CSV templates for movie import"
  task generate_templates: :environment do
    require 'csv'
    
    dir = Rails.root.join('tmp', 'import')
    FileUtils.mkdir_p(dir)
    
    # Movies template
    CSV.open(dir.join('movies_template.csv'), 'w') do |csv|
      csv << ['id', 'title', 'director', 'year', 'url', 'score', 'created_at', 'updated_at']
      csv << [1, 'The Shawshank Redemption', 'Frank Darabont', 1994, 
              'https://www.themoviedb.org/movie/278-the-shawshank-redemption', 90]
      csv << [2, 'The Godfather', 'Francis Ford Coppola', 1972,
              'https://www.themoviedb.org/movie/238', 95]
    end
    
    # Theaters template
    CSV.open(dir.join('theaters_template.csv'), 'w') do |csv|
      csv << ['id', 'name', 'city', 'state', 'country', 'notes']
      csv << [1, 'AMC Metreon 16', 'San Francisco', 'CA', 'USA', 'Downtown location']
      csv << [2, 'Alamo Drafthouse', 'Brooklyn', 'NY', 'USA', 'Full service theater']
    end
    
    # Film Series template
    CSV.open(dir.join('film_series_template.csv'), 'w') do |csv|
      csv << ['id', 'name', 'description']
      csv << [1, 'Criterion Collection', 'Classic and contemporary films']
      csv << [2, 'Marvel Cinematic Universe', 'MCU film series']
    end
    
    # Film Series Events template
    CSV.open(dir.join('film_series_events_template.csv'), 'w') do |csv|
      csv << ['id', 'name', 'film_series_id', 'started_on', 'ended_on', 'notes']
      csv << [1, 'Summer Classics 2024', 1, '2024-06-01', '2024-08-31', 'Summer screening series']
      csv << [2, 'Phase 4', 2, '2021-01-01', '2023-12-31', 'MCU Phase 4']
    end
    
    # Viewings template
    CSV.open(dir.join('viewings_template.csv'), 'w') do |csv|
      csv << ['id', 'viewable_id', 'viewed_on', 'home', 'theater_id', 
              'film_series_event_id', 'price', 'viewed_at', 'notes', 'rewatch']
      csv << [1, 1, '2024-01-15', false, 1, nil, 15.00, 
              '2024-01-15 19:30:00', 'Great experience!', false]
      csv << [2, 2, '2024-02-20', true, nil, nil, nil, 
              '2024-02-20 20:00:00', 'Movie night at home', false]
    end
    
    puts "✓ Generated CSV templates in #{dir}"
    puts "  - movies_template.csv"
    puts "  - theaters_template.csv"
    puts "  - film_series_template.csv"
    puts "  - film_series_events_template.csv"
    puts "  - viewings_template.csv"
  end
  
  desc "Validate import data before running import"
  task validate_import: :environment do
    require 'csv'
    
    dir = Rails.root.join('tmp', 'import')
    issues = []
    
    # Check movies.csv
    if File.exist?(dir.join('movies.csv'))
      ids = []
      CSV.foreach(dir.join('movies.csv'), headers: true) do |row|
        ids << row['id'].to_i if row['id']
      end
      duplicates = ids.select { |id| ids.count(id) > 1 }.uniq
      issues << "Duplicate movie IDs: #{duplicates.join(', ')}" if duplicates.any?
    else
      issues << "movies.csv not found"
    end
    
    # Check viewings.csv references
    if File.exist?(dir.join('viewings.csv'))
      movie_ids = []
      theater_ids = []
      event_ids = []
      
      CSV.foreach(dir.join('viewings.csv'), headers: true) do |row|
        movie_ids << (row['viewable_id'] || row['movie_id'])&.to_i
        theater_ids << row['theater_id']&.to_i if row['theater_id']
        event_ids << row['film_series_event_id']&.to_i if row['film_series_event_id']
      end
      
      # Check for missing movies
      if File.exist?(dir.join('movies.csv'))
        valid_movie_ids = CSV.read(dir.join('movies.csv'), headers: true).map { |r| r['id']&.to_i }.compact
        missing_movies = movie_ids.uniq - valid_movie_ids - [nil, 0]
        issues << "Viewings reference missing movie IDs: #{missing_movies.join(', ')}" if missing_movies.any?
      end
    else
      issues << "viewings.csv not found"
    end
    
    if issues.any?
      puts "⚠️  Validation issues found:"
      issues.each { |issue| puts "  - #{issue}" }
    else
      puts "✓ Validation passed - ready to import!"
    end
  end
end
