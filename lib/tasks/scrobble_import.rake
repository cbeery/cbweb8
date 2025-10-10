# lib/tasks/scrobble_import.rake
#
# Import scrobble data from CSV files
# 
# Import order matters due to relationships:
#   1. Artists (no dependencies)
#   2. Albums (depends on artists)
#   3. Plays (depends on artists and albums)
#   4. Top scrobbles (independent)
#   5. Counts (independent)
#
# Usage examples:
#   rails scrobble:import_artists[data/scrobble_artists.csv]
#   rails scrobble:import_albums[data/scrobble_albums.csv]
#   rails scrobble:import_plays[data/scrobble_plays.csv]
#   rails scrobble:import_top_scrobbles[data/top_scrobbles.csv]
#   rails scrobble:import_from_csv[data/scrobble_counts.csv]
#
namespace :scrobble do
  desc "Import daily scrobble counts from CSV"
  task :import_daily_counts, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails scrobble:import_from_csv[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing scrobble counts from #{args[:file_path]}..."
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = []
    skipped_imports = []
    updated_imports = 0
    
    CSV.foreach(args[:file_path], headers: true, header_converters: :symbol).with_index do |row, index|
      begin
        # Parse the row data
        scrobble_id = row[:id]&.strip
        date_string = row[:date]&.strip
        plays = row[:plays]&.to_i
        created_at = row[:created_at]&.strip
        updated_at = row[:updated_at]&.strip
        
        # Skip if essential data is missing
        if date_string.blank? || plays.blank?
          skipped_imports << {
            row: index + 2,
            info: "Date: #{date_string || 'MISSING'}, Plays: #{plays || 'MISSING'}",
            reason: "Missing required fields"
          }
          next
        end
        
        # Parse the date for played_on field
        played_on = begin
          Date.parse(date_string)
        rescue ArgumentError => e
          failed_imports << {
            row: index + 2,
            info: "Date: '#{date_string}'",
            error: "Invalid date format: #{e.message}"
          }
          next
        end
        
        # Check for duplicates by date
        if ScrobbleCount.exists?(played_on: played_on)
          existing = ScrobbleCount.find_by(played_on: played_on)
          
          # Update if plays count is different
          if existing.plays != plays
            existing.update!(plays: plays)
            puts "📝 Updated: #{played_on} - plays: #{existing.plays} → #{plays}"
            updated_imports += 1
          else
            skipped_imports << {
              row: index + 2,
              info: played_on.to_s,
              reason: "Already exists with same play count (#{plays})"
            }
          end
          next
        end
        
        # Parse timestamps if provided
        timestamps = {}
        if created_at.present?
          begin
            timestamps[:created_at] = DateTime.parse(created_at)
          rescue ArgumentError
            # Ignore invalid timestamp, will use Rails default
          end
        end
        
        if updated_at.present?
          begin
            timestamps[:updated_at] = DateTime.parse(updated_at)
          rescue ArgumentError
            # Ignore invalid timestamp, will use Rails default
          end
        end
        
        # Create the scrobble count
        scrobble = ScrobbleCount.create!(
          played_on: played_on,
          plays: plays,
          **timestamps
        )
        
        puts "✅ Imported: #{played_on.strftime('%Y-%m-%d')} - #{plays} plays"
        successful_imports += 1
        
      rescue ActiveRecord::RecordInvalid => e
        failed_imports << {
          row: index + 2,
          info: "Date: #{row[:date]}",
          error: e.message
        }
      rescue => e
        failed_imports << {
          row: index + 2,
          info: "Date: #{row[:date]}",
          error: e.message
        }
      end
    end
    
    puts "-" * 50
    puts "Import Complete!"
    puts "✅ Successful: #{successful_imports}"
    puts "📝 Updated: #{updated_imports}" if updated_imports > 0
    puts "⚠️  Skipped: #{skipped_imports.size}" if skipped_imports.any?
    puts "❌ Failed: #{failed_imports.size}" if failed_imports.any?
    
    if skipped_imports.any? && skipped_imports.size <= 20
      puts "\n⚠️  SKIPPED DETAILS:"
      skipped_imports.each do |skip|
        puts "  Row #{skip[:row]}: #{skip[:info]} - #{skip[:reason]}"
      end
    elsif skipped_imports.any?
      puts "\n⚠️  SKIPPED: #{skipped_imports.size} records (too many to list)"
    end
    
    if failed_imports.any?
      puts "\n❌ FAILED DETAILS:"
      failed_imports.each do |failure|
        puts "  Row #{failure[:row]}: #{failure[:info]} - #{failure[:error]}"
      end
    end
    
    # Show summary statistics
    if successful_imports > 0 || updated_imports > 0
      total_plays = ScrobbleCount.sum(:plays)
      date_range = ScrobbleCount.order(:played_on)
      
      puts "\n📊 Summary:"
      puts "  Total scrobbles in database: #{ScrobbleCount.count}"
      puts "  Total plays: #{number_with_delimiter(total_plays)}"
      puts "  Date range: #{date_range.first.played_on} to #{date_range.last.played_on}"
    end
  end
  
  desc "Import artists from CSV"
  task :import_artists, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails scrobble:import_artists[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing scrobble artists from #{args[:file_path]}..."
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = []
    skipped_imports = []
    
    # Use liberal_parsing to handle quotes within quotes
    csv_options = {
      headers: true,
      header_converters: :symbol,
      liberal_parsing: true  # This handles quotes within quoted fields
    }
    
    CSV.foreach(args[:file_path], **csv_options).with_index do |row, index|
      begin
        artist_id = row[:id]&.to_i
        name = row[:name]&.strip
        created_at = row[:created_at]&.strip
        updated_at = row[:updated_at]&.strip
        
        if name.blank?
          skipped_imports << { row: index + 2, name: "BLANK", reason: "Missing artist name" }
          next
        end
        
        # Check for existing artist by ID or name
        existing_artist = ScrobbleArtist.find_by(id: artist_id) || ScrobbleArtist.find_by(name: name)
        
        if existing_artist
          skipped_imports << { row: index + 2, name: name, reason: "Already exists (ID: #{existing_artist.id})" }
          next
        end
        
        # Parse timestamps
        timestamps = {}
        timestamps[:created_at] = DateTime.parse(created_at) if created_at.present?
        timestamps[:updated_at] = DateTime.parse(updated_at) if updated_at.present?
        
        # Create with specific ID if provided
        artist = ScrobbleArtist.new(
          name: name,
          **timestamps
        )
        artist.id = artist_id if artist_id
        artist.save!
        
        puts "✅ Imported: #{name} (ID: #{artist.id})"
        successful_imports += 1
        
      rescue => e
        failed_imports << { row: index + 2, name: row[:name] || "UNKNOWN", error: e.message }
      end
    end
    
    puts "-" * 50
    puts "Artist Import Complete!"
    puts "✅ Successful: #{successful_imports}"
    puts "⚠️  Skipped: #{skipped_imports.size}" if skipped_imports.any?
    puts "❌ Failed: #{failed_imports.size}" if failed_imports.any?
    
    if skipped_imports.any?
      puts "\n⚠️  SKIPPED DETAILS:"
      skipped_imports.first(10).each do |skip|
        puts "  Row #{skip[:row]}: '#{skip[:name]}' - #{skip[:reason]}"
      end
      puts "  ... and #{skipped_imports.size - 10} more" if skipped_imports.size > 10
    end
    
    if failed_imports.any?
      puts "\n❌ FAILED DETAILS:"
      failed_imports.each do |failure|
        puts "  Row #{failure[:row]}: '#{failure[:name]}' - #{failure[:error]}"
      end
    end
  end
  
  desc "Import albums from CSV"
  task :import_albums, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails scrobble:import_albums[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing scrobble albums from #{args[:file_path]}..."
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = []
    skipped_imports = []
    
    # Use liberal_parsing to handle quotes within quotes
    csv_options = {
      headers: true,
      header_converters: :symbol,
      liberal_parsing: true
    }
    
    CSV.foreach(args[:file_path], **csv_options).with_index do |row, index|
      begin
        album_id = row[:id]&.to_i
        name = row[:name]&.strip
        artist_id = row[:scrobble_artist_id]&.to_i
        created_at = row[:created_at]&.strip
        updated_at = row[:updated_at]&.strip
        
        if name.blank? || artist_id.blank?
          skipped_imports << { 
            row: index + 2, 
            name: name || "BLANK", 
            reason: "Missing #{name.blank? ? 'album name' : 'artist ID'}" 
          }
          next
        end
        
        # Verify artist exists
        artist = ScrobbleArtist.find_by(id: artist_id)
        unless artist
          failed_imports << { 
            row: index + 2, 
            name: name, 
            error: "Artist ID #{artist_id} not found in database" 
          }
          next
        end
        
        # Check for existing album
        existing_album = ScrobbleAlbum.find_by(id: album_id) || 
                        ScrobbleAlbum.find_by(name: name, scrobble_artist_id: artist_id)
        
        if existing_album
          skipped_imports << { 
            row: index + 2, 
            name: "#{name} by #{artist.name}", 
            reason: "Already exists (ID: #{existing_album.id})" 
          }
          next
        end
        
        # Parse timestamps
        timestamps = {}
        timestamps[:created_at] = DateTime.parse(created_at) if created_at.present?
        timestamps[:updated_at] = DateTime.parse(updated_at) if updated_at.present?
        
        # Create with specific ID if provided
        album = ScrobbleAlbum.new(
          name: name,
          scrobble_artist_id: artist_id,
          **timestamps
        )
        album.id = album_id if album_id
        album.save!
        
        puts "✅ Imported: '#{name}' by #{artist.name} (ID: #{album.id})"
        successful_imports += 1
        
      rescue => e
        failed_imports << { 
          row: index + 2, 
          name: "#{row[:name]} (Artist ID: #{row[:scrobble_artist_id]})", 
          error: e.message 
        }
      end
    end
    
    puts "-" * 50
    puts "Album Import Complete!"
    puts "✅ Successful: #{successful_imports}"
    puts "⚠️  Skipped: #{skipped_imports.size}" if skipped_imports.any?
    puts "❌ Failed: #{failed_imports.size}" if failed_imports.any?
    
    if skipped_imports.any?
      puts "\n⚠️  SKIPPED DETAILS:"
      skipped_imports.first(10).each do |skip|
        puts "  Row #{skip[:row]}: '#{skip[:name]}' - #{skip[:reason]}"
      end
      puts "  ... and #{skipped_imports.size - 10} more" if skipped_imports.size > 10
    end
    
    if failed_imports.any?
      puts "\n❌ FAILED DETAILS:"
      failed_imports.each do |failure|
        puts "  Row #{failure[:row]}: '#{failure[:name]}' - #{failure[:error]}"
      end
    end
  end
  
  desc "Import play history from CSV"
  task :import_plays, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails scrobble:import_plays[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing scrobble plays from #{args[:file_path]}..."
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = []
    skipped_imports = []
    updated_imports = 0
    
    # Process in batches for performance
    batch_size = 500
    batch_count = 0
    row_count = 0
    
    # Use liberal_parsing to handle quotes within quotes
    csv_options = {
      headers: true,
      header_converters: :symbol,
      liberal_parsing: true
    }
    
    CSV.foreach(args[:file_path], **csv_options).with_index.each_slice(batch_size) do |batch|
      batch_count += 1
      batch_start = row_count + 1
      row_count += batch.size
      puts "\nProcessing batch #{batch_count} (rows #{batch_start}-#{row_count})..."
      
      batch.each do |row_with_index|
        row, csv_index = row_with_index
        row_number = csv_index + 2  # +2 for header and 0-index
        
        begin
          # Don't preserve ID for plays - let Rails generate new ones
          artist_id = row[:scrobble_artist_id]&.to_i
          album_id = row[:scrobble_album_id]&.to_i
          plays = row[:plays]&.to_i
          date = row[:date]&.strip
          category = row[:category]&.strip
          created_at = row[:created_at]&.strip
          updated_at = row[:updated_at]&.strip
          
          if artist_id.blank? || plays.blank? || date.blank?
            skipped_imports << {
              row: row_number,
              info: "Artist: #{artist_id || 'MISSING'}, Date: #{date || 'MISSING'}",
              reason: "Missing required fields"
            }
            next
          end
          
          # Verify artist exists
          unless ScrobbleArtist.exists?(artist_id)
            failed_imports << {
              row: row_number,
              info: "Artist ID: #{artist_id}, Date: #{date}",
              error: "Artist ID #{artist_id} not found"
            }
            next
          end
          
          # Verify album exists if provided
          if album_id.present? && album_id > 0
            unless ScrobbleAlbum.exists?(album_id)
              failed_imports << {
                row: row_number,
                info: "Album ID: #{album_id}, Artist ID: #{artist_id}",
                error: "Album ID #{album_id} not found"
              }
              next
            end
          else
            album_id = nil
          end
          
          # Parse date for played_on field
          played_on = Date.parse(date) rescue nil
          unless played_on
            failed_imports << {
              row: row_number,
              info: "Date: '#{date}'",
              error: "Invalid date format"
            }
            next
          end
          
          # Check for existing play
          existing_play = ScrobblePlay.find_by(
            scrobble_artist_id: artist_id,
            scrobble_album_id: album_id,
            played_on: played_on,
            category: category
          )
          
          if existing_play
            if existing_play.plays != plays
              existing_play.update!(plays: plays)
              updated_imports += 1
            else
              skipped_imports << {
                row: row_number,
                info: "Artist: #{artist_id}, Date: #{played_on}",
                reason: "Already exists with same play count"
              }
            end
            next
          end
          
          # Parse timestamps
          timestamps = {}
          timestamps[:created_at] = DateTime.parse(created_at) if created_at.present?
          timestamps[:updated_at] = DateTime.parse(updated_at) if updated_at.present?
          
          # Create play record (without setting ID)
          play = ScrobblePlay.create!(
            scrobble_artist_id: artist_id,
            scrobble_album_id: album_id,
            plays: plays,
            played_on: played_on,  # Map date to played_on field
            category: category || 'artist',
            **timestamps
          )
          
          successful_imports += 1
          print "." if successful_imports % 10 == 0
          
        rescue => e
          failed_imports << {
            row: row_number,
            info: "Artist: #{artist_id}, Date: #{date}",
            error: e.message
          }
        end
      end
    end
    
    puts "\n" + "-" * 50
    puts "Play Import Complete!"
    puts "✅ Successful: #{successful_imports}"
    puts "📝 Updated: #{updated_imports}" if updated_imports > 0
    puts "⚠️  Skipped: #{skipped_imports.size}" if skipped_imports.any?
    puts "❌ Failed: #{failed_imports.size}" if failed_imports.any?
    
    if skipped_imports.any? && skipped_imports.size <= 20
      puts "\n⚠️  SKIPPED DETAILS:"
      skipped_imports.each do |skip|
        puts "  Row #{skip[:row]}: #{skip[:info]} - #{skip[:reason]}"
      end
    elsif skipped_imports.any?
      puts "\n⚠️  SKIPPED: #{skipped_imports.size} records (too many to list)"
    end
    
    if failed_imports.any?
      puts "\n❌ FAILED DETAILS:"
      failed_imports.first(20).each do |failure|
        puts "  Row #{failure[:row]}: #{failure[:info]} - #{failure[:error]}"
      end
      puts "  ... and #{failed_imports.size - 20} more" if failed_imports.size > 20
    end
  end
  
  desc "Import top scrobbles from CSV"
  task :import_top_scrobbles, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails scrobble:import_top_scrobbles[path/to/file.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing top scrobbles from #{args[:file_path]}..."
    puts "-" * 50
    
    successful_imports = 0
    failed_imports = []
    skipped_imports = []
    updated_imports = 0
    
    # Use liberal_parsing to handle quotes within quotes
    csv_options = {
      headers: true,
      header_converters: :symbol,
      liberal_parsing: true
    }
    
    CSV.foreach(args[:file_path], **csv_options).with_index do |row, index|
      begin
        top_id = row[:id]&.to_i
        category = row[:category]&.strip
        period = row[:period]&.strip
        artist = row[:artist]&.strip
        name = row[:name]&.strip
        rank = row[:rank]&.to_i
        position = row[:position]&.to_i
        plays = row[:plays]&.to_i
        url = row[:url]&.strip
        created_at = row[:created_at]&.strip
        updated_at = row[:updated_at]&.strip
        revised_at = row[:revised_at]&.strip
        
        if category.blank? || period.blank? || artist.blank? || rank.blank?
          skipped_imports << {
            row: index + 2,
            info: "Artist: #{artist || 'MISSING'}, Period: #{period || 'MISSING'}",
            reason: "Missing required fields"
          }
          next
        end
        
        # Check for existing top scrobble
        existing_top = TopScrobble.find_by(
          category: category,
          period: period,
          artist: artist,
          rank: rank
        )
        
        if existing_top
          # Update if data has changed
          if existing_top.plays != plays || existing_top.position != position
            existing_top.update!(
              plays: plays,
              position: position || rank,
              revised_at: revised_at.present? ? DateTime.parse(revised_at) : DateTime.now,
              url: url
            )
            puts "📝 Updated: #{artist} - #{period} rank #{rank}"
            updated_imports += 1
          else
            skipped_imports << {
              row: index + 2,
              info: "#{artist} - #{period} rank #{rank}",
              reason: "Already exists with same data"
            }
          end
          next
        end
        
        # Parse timestamps
        timestamps = {}
        timestamps[:created_at] = DateTime.parse(created_at) if created_at.present?
        timestamps[:updated_at] = DateTime.parse(updated_at) if updated_at.present?
        timestamps[:revised_at] = DateTime.parse(revised_at) if revised_at.present?
        
        # Create top scrobble
        top_scrobble = TopScrobble.new(
          category: category,
          period: period,
          artist: artist,
          name: name,
          rank: rank,
          position: position || rank,
          plays: plays,
          url: url,
          **timestamps
        )
        top_scrobble.id = top_id if top_id
        top_scrobble.save!
        
        puts "✅ Imported: #{artist} - #{period} rank #{rank} (#{plays} plays)"
        successful_imports += 1
        
      rescue => e
        failed_imports << {
          row: index + 2,
          info: "#{row[:artist]} - #{row[:period]}",
          error: e.message
        }
      end
    end
    
    puts "-" * 50
    puts "Top Scrobbles Import Complete!"
    puts "✅ Successful: #{successful_imports}"
    puts "📝 Updated: #{updated_imports}" if updated_imports > 0
    puts "⚠️  Skipped: #{skipped_imports.size}" if skipped_imports.any?
    puts "❌ Failed: #{failed_imports.size}" if failed_imports.any?
    
    if skipped_imports.any? && skipped_imports.size <= 20
      puts "\n⚠️  SKIPPED DETAILS:"
      skipped_imports.each do |skip|
        puts "  Row #{skip[:row]}: #{skip[:info]} - #{skip[:reason]}"
      end
    elsif skipped_imports.any?
      puts "\n⚠️  SKIPPED: #{skipped_imports.size} records (too many to list)"
    end
    
    if failed_imports.any?
      puts "\n❌ FAILED DETAILS:"
      failed_imports.each do |failure|
        puts "  Row #{failure[:row]}: #{failure[:info]} - #{failure[:error]}"
      end
    end
    
    # Show summary
    if successful_imports > 0 || updated_imports > 0
      puts "\n📊 Summary by period:"
      TopScrobble.group(:period).count.each do |period, count|
        puts "  #{period}: #{count} entries"
      end
    end
  end
  
  desc "Generate sample CSV template"
  task generate_csv_template: :environment do
    require 'csv'
    
    filename = "scrobble_counts_template.csv"
    
    CSV.open(filename, "w") do |csv|
      csv << ["id", "date", "plays", "created_at", "updated_at"]
      csv << ["1", Date.today.to_s, "42", DateTime.now.iso8601, DateTime.now.iso8601]
      csv << ["2", (Date.today - 1.day).to_s, "38", DateTime.now.iso8601, DateTime.now.iso8601]
      csv << ["3", (Date.today - 2.days).to_s, "45", DateTime.now.iso8601, DateTime.now.iso8601]
    end
    
    puts "Generated template file: #{filename}"
    puts "Edit this file with your scrobble data, then run:"
    puts "  rails scrobble:import_from_csv[#{filename}]"
  end
  
  desc "Show scrobble statistics"
  task stats: :environment do
    puts "=" * 60
    puts "Scrobble Database Statistics"
    puts "=" * 60
    
    # Basic counts
    puts "\n📊 TOTALS:"
    puts "  Artists: #{ScrobbleArtist.count}"
    puts "  Albums: #{ScrobbleAlbum.count}"
    puts "  Play records: #{ScrobblePlay.count}"
    puts "  Top scrobbles: #{TopScrobble.count}"
    puts "  Daily counts: #{ScrobbleCount.count}"
    
    # ScrobbleCount stats
    if ScrobbleCount.any?
      total_plays = ScrobbleCount.sum(:plays)
      avg_plays = ScrobbleCount.average(:plays)&.round(1)
      date_range = ScrobbleCount.order(:played_on)
      first_date = date_range.first.played_on
      last_date = date_range.last.played_on
      
      puts "\n📅 DAILY SCROBBLES:"
      puts "  Total plays: #{number_with_delimiter(total_plays)}"
      puts "  Average plays/day: #{avg_plays}"
      puts "  Date range: #{first_date} to #{last_date}"
    end
    
    # Top artists by total plays
    if ScrobblePlay.any?
      puts "\n🎵 TOP ARTISTS (by play records):"
      top_artists = ScrobblePlay.group(:scrobble_artist_id)
                                .sum(:plays)
                                .sort_by { |_, plays| -plays }
                                .first(5)
      
      top_artists.each_with_index do |(artist_id, plays), index|
        artist = ScrobbleArtist.find_by(id: artist_id)
        puts "  #{index + 1}. #{artist&.name || 'Unknown'}: #{number_with_delimiter(plays)} plays"
      end
      
      # Show date range of play records
      date_range = ScrobblePlay.order(:played_on)
      if date_range.any?
        puts "\n📆 PLAY RECORDS DATE RANGE:"
        puts "  First: #{date_range.first.played_on}"
        puts "  Last: #{date_range.last.played_on}"
      end
    end
    
    # Top scrobble periods
    if TopScrobble.any?
      puts "\n📈 TOP SCROBBLES BY PERIOD:"
      TopScrobble.group(:period).count.each do |period, count|
        puts "  #{period}: #{count} entries"
      end
    end
    
    puts "\n" + "=" * 60
  end
  
  private
  
  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
