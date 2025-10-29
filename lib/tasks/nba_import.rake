# lib/tasks/nba_import.rake
namespace :nba do

  desc "Import NBA teams from legacy CSV"
  task :import_teams_legacy, [:file_path] => :environment do |t, args|
    require 'csv'

    # TEMPORARY: Disable SSL verification for S3 uploads during import
    # Remove this in production!
    if Rails.env.development?
      require 'openssl'
      OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
    end

    unless args[:file_path]
      puts "Usage: rails nba:import_teams_legacy[path/to/teams.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    # Determine logo directory path (subfolder of CSV location)
    csv_dir = File.dirname(args[:file_path])
    logo_dir = File.join(csv_dir, 'nba_logos')
    
    puts "Importing NBA teams from #{args[:file_path]}..."
    puts "Looking for logos in: #{logo_dir}"
    puts "-" * 50
    
    successful = 0
    failed = 0
    skipped = 0
    logos_attached = 0
    max_id = 0
    
    CSV.foreach(args[:file_path], headers: true, header_converters: :symbol) do |row|
      begin
        # Extract ID from legacy data
        legacy_id = row[:id]&.to_i
        
        # Legacy schema has these columns: id, city, name, abbreviation, logo, color
        city = row[:city]&.strip
        name = row[:name]&.strip
        abbreviation = row[:abbreviation]&.strip&.upcase
        color = row[:color]&.strip
        
        # Skip if essential data is missing
        if name.blank? || abbreviation.blank? || city.blank?
          puts "⚠️  Skipping row - missing required fields (city, name, or abbreviation)"
          skipped += 1
          next
        end
        
        # Check for duplicates (by ID or abbreviation)
        if legacy_id && NbaTeam.exists?(id: legacy_id)
          puts "⚠️  Team with ID #{legacy_id} already exists"
          skipped += 1
          next
        end
        
        if NbaTeam.exists?(abbreviation: abbreviation)
          puts "⚠️  Team #{abbreviation} already exists"
          skipped += 1
          next
        end
        
        # Create team with explicit ID if provided
        team_attributes = {
          city: city,
          name: name,
          abbreviation: abbreviation,
          color: color,
          active: true
        }
        
        # Add ID if present in CSV
        team_attributes[:id] = legacy_id if legacy_id && legacy_id > 0
        
        team = NbaTeam.create!(team_attributes)
        
        # Track the highest ID for sequence reset
        max_id = [max_id, team.id].max
        
        # Attach logo if it exists
        logo_path = File.join(logo_dir, "#{abbreviation.downcase}.png")
        if File.exist?(logo_path)
          team.logo.attach(
            io: File.open(logo_path),
            filename: "#{abbreviation.downcase}.png",
            content_type: 'image/png'
          )
          logos_attached += 1
          puts "✅ Imported: #{team.display_name} (#{abbreviation}) [ID: #{team.id}] with logo"
        else
          puts "✅ Imported: #{team.display_name} (#{abbreviation}) [ID: #{team.id}] - no logo found"
        end
        
        successful += 1
        
      rescue => e
        puts "❌ Failed to import row: #{e.message}"
        puts "   Row data: #{row.to_h}"
        failed += 1
      end
    end
    
    # Reset PostgreSQL sequence to avoid conflicts with future inserts
    if successful > 0 && max_id > 0
      ActiveRecord::Base.connection.execute(
        "SELECT setval('nba_teams_id_seq', #{max_id}, true)"
      )
      puts "\n✅ Reset ID sequence to: #{max_id}"
    end
    
    puts "-" * 50
    puts "Import Complete!"
    puts "✅ Successful: #{successful}"
    puts "🖼️  Logos attached: #{logos_attached}"
    puts "⚠️  Skipped: #{skipped}" if skipped > 0
    puts "❌ Failed: #{failed}" if failed > 0
    
    # Add conference/division data if needed
    puts "\n💡 Tip: You may want to update conference and division data manually or via Rails console"
  end
  
  desc "Import NBA games from legacy CSV"
  task :import_games_legacy, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails nba:import_games_legacy[path/to/games.csv]"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing NBA games from #{args[:file_path]}..."
    puts "-" * 50
    
    successful = 0
    failed = 0
    skipped = 0
    
    CSV.foreach(args[:file_path], headers: true, header_converters: :symbol) do |row|
      begin
        # Try to find teams by ID first (if migrating with same IDs), then by abbreviation
        home_team = if row[:home_id].present?
                      NbaTeam.find_by(id: row[:home_id])
                    elsif row[:home_abbreviation].present?
                      NbaTeam.find_by(abbreviation: row[:home_abbreviation]&.strip&.upcase)
                    else
                      nil
                    end
                    
        away_team = if row[:away_id].present?
                      NbaTeam.find_by(id: row[:away_id])
                    elsif row[:away_abbreviation].present?
                      NbaTeam.find_by(abbreviation: row[:away_abbreviation]&.strip&.upcase)
                    else
                      nil
                    end
        
        unless home_team && away_team
          puts "⚠️  Skipping row - team not found (home: #{row[:home_id] || row[:home_abbreviation]}, away: #{row[:away_id] || row[:away_abbreviation]})"
          skipped += 1
          next
        end
        
        # Parse date
        played_on = Date.parse(row[:played_on].to_s)
        
        # Check for duplicate
        if NbaGame.exists?(home_id: home_team.id, away_id: away_team.id, played_on: played_on)
          puts "⚠️  Game already exists: #{away_team.abbreviation} @ #{home_team.abbreviation} on #{played_on}"
          skipped += 1
          next
        end
        
        # Parse datetime if available
        played_at = nil
        if row[:played_at].present?
          begin
            played_at = DateTime.parse(row[:played_at])
          rescue
            puts "   Warning: Could not parse played_at: #{row[:played_at]}"
          end
        elsif row[:gametime].present? && row[:played_on].present?
          # Try to combine date and time
          begin
            time_str = row[:gametime].strip
            played_at = DateTime.parse("#{row[:played_on]} #{time_str}")
          rescue
            # Keep gametime as string if can't parse
          end
        end
        
        # Parse boolean fields - handle various formats
        preseason = case row[:preseason]&.to_s&.downcase
                    when 'true', 't', '1', 'yes' then true
                    when 'false', 'f', '0', 'no', nil, '' then false
                    else false
                    end
                    
        postseason = case row[:postseason]&.to_s&.downcase
                     when 'true', 't', '1', 'yes' then true
                     when 'false', 'f', '0', 'no', nil, '' then false
                     else false
                     end
        
        game = NbaGame.create!(
          home_id: home_team.id,
          away_id: away_team.id,
          played_on: played_on,
          played_at: played_at,
          gametime: row[:gametime]&.strip,
          season: row[:season]&.strip || NbaGame.current_season,
          
          # Game type
          preseason: preseason,
          postseason: postseason,
          
          # Playoff details - only set if values are present
          playoff_round: row[:playoff_round].present? ? row[:playoff_round].to_i : nil,
          playoff_conference: row[:playoff_conference].present? ? row[:playoff_conference].strip : nil,
          playoff_series_game_number: row[:playoff_series_game_number].present? ? row[:playoff_series_game_number].to_i : nil,
          
          # Results
          home_score: row[:home_score]&.to_i,
          away_score: row[:away_score]&.to_i,
          overtimes: row[:overtimes]&.to_i || 0,
          
          # Viewing
          quarters_watched: row[:quarters_watched]&.to_i || 0,
          network: row[:network]&.strip,
          screen: row[:screen]&.strip,
          place: row[:place]&.strip,
          
          # Position for ordering
          position: row[:position]&.to_i
        )
        
        type_suffix = " (Playoffs)" if game.postseason
        type_suffix = " (Preseason)" if game.preseason
        puts "✅ Imported: #{game.display_name} on #{played_on}#{type_suffix}"
        successful += 1
        
      rescue => e
        puts "❌ Failed to import row: #{e.message}"
        puts "   Row data: #{row.to_h.slice(:home_id, :away_id, :played_on)}"
        failed += 1
      end
    end
    
    puts "-" * 50
    puts "Import Complete!"
    puts "✅ Successful: #{successful}"
    puts "⚠️  Skipped: #{skipped}" if skipped > 0
    puts "❌ Failed: #{failed}" if failed > 0
    
    # Show summary stats
    if successful > 0
      puts "\n📊 Quick Stats:"
      puts "  Total games in database: #{NbaGame.count}"
      puts "  Games with scores: #{NbaGame.where.not(home_score: nil).count}"
      puts "  Games watched: #{NbaGame.watched.count}"
      puts "  Playoff games: #{NbaGame.playoffs.count}"
    end
  end

  desc "Import teams with conference/division data"
  task :import_teams_with_conferences, [:file_path] => :environment do |t, args|
    require 'csv'
    
    unless args[:file_path]
      puts "Usage: rails nba:import_teams_with_conferences[path/to/teams.csv]"
      puts "CSV should have columns: city,name,abbreviation,conference,division,color"
      exit
    end
    
    unless File.exist?(args[:file_path])
      puts "Error: File not found: #{args[:file_path]}"
      exit
    end
    
    puts "Importing NBA teams from #{args[:file_path]}..."
    puts "-" * 50
    
    successful = 0
    updated = 0
    failed = 0
    
    CSV.foreach(args[:file_path], headers: true, header_converters: :symbol) do |row|
      begin
        abbreviation = row[:abbreviation]&.strip&.upcase
        
        # Try to find existing team
        team = NbaTeam.find_by(abbreviation: abbreviation)
        
        if team
          # Update existing team
          team.update!(
            city: row[:city]&.strip || team.city,
            name: row[:name]&.strip || team.name,
            conference: row[:conference]&.strip || team.conference,
            division: row[:division]&.strip || team.division,
            color: row[:color]&.strip || team.color
          )
          puts "📝 Updated: #{team.display_name} - #{team.conference} #{team.division}"
          updated += 1
        else
          # Create new team
          team = NbaTeam.create!(
            city: row[:city]&.strip,
            name: row[:name]&.strip,
            abbreviation: abbreviation,
            conference: row[:conference]&.strip,
            division: row[:division]&.strip,
            color: row[:color]&.strip,
            active: true
          )
          puts "✅ Created: #{team.display_name} - #{team.conference} #{team.division}"
          successful += 1
        end
        
      rescue => e
        puts "❌ Failed: #{e.message}"
        failed += 1
      end
    end
    
    puts "-" * 50
    puts "Import Complete!"
    puts "✅ Created: #{successful}" if successful > 0
    puts "📝 Updated: #{updated}" if updated > 0
    puts "❌ Failed: #{failed}" if failed > 0
  end

  desc "Generate sample CSV templates"
  task generate_templates: :environment do
    # Generate teams template
    teams_file = "nba_teams_template.csv"
    CSV.open(teams_file, "w") do |csv|
      csv << ["city", "name", "abbreviation", "conference", "division", "color"]
      csv << ["Los Angeles", "Lakers", "LAL", "Western", "Pacific", "#552583"]
      csv << ["Boston", "Celtics", "BOS", "Eastern", "Atlantic", "#007A33"]
      csv << ["Golden State", "Warriors", "GSW", "Western", "Pacific", "#006BB6"]
    end
    puts "Generated: #{teams_file}"
    
    # Generate games template
    games_file = "nba_games_template.csv"
    CSV.open(games_file, "w") do |csv|
      csv << ["home_id", "away_id", "played_on", "season", "gametime", "home_score", "away_score", 
              "quarters_watched", "network", "screen", "place", "preseason", "postseason", 
              "playoff_round", "playoff_conference", "playoff_series_game_number", "overtimes", "position"]
      csv << ["1", "2", "2024-12-25", "2024-25", "8:00 PM ET", "110", "105", 
              "4", "ABC", "TV", "Home", "false", "false", 
              "", "", "", "0", "1"]
      csv << ["3", "1", "2024-06-10", "2023-24", "9:00 PM ET", "108", "106", 
              "4", "ABC", "TV", "Home", "false", "true", 
              "4", "", "3", "1", "1"]
    end
    puts "Generated: #{games_file}"
    
    puts "\n📝 Edit these template files with your data, then run:"
    puts "  rails nba:import_teams_legacy[#{teams_file}]"
    puts "  rails nba:import_games_legacy[#{games_file}]"
  end

  desc "Generate stats for imported games"
  task stats: :environment do
    puts "\n📊 NBA Games Statistics"
    puts "=" * 50
    
    total_games = NbaGame.count
    watched_games = NbaGame.watched.count
    fully_watched = NbaGame.fully_watched.count
    
    puts "Total games: #{total_games}"
    puts "Games watched: #{watched_games} (#{(watched_games.to_f / total_games * 100).round(1)}%)"
    puts "Fully watched: #{fully_watched}"
    puts "Overtime games: #{NbaGame.overtime_games.count}"
    
    puts "\n📅 By Season:"
    NbaGame.group(:season).count.sort.each do |season, count|
      watched = NbaGame.by_season(season).watched.count
      puts "  #{season}: #{count} games (#{watched} watched)"
    end
    
    puts "\n🏆 Playoff Games:"
    playoff_games = NbaGame.playoffs
    puts "  Total: #{playoff_games.count}"
    puts "  Watched: #{playoff_games.watched.count}"
    
    if playoff_games.any?
      puts "\n  By Round:"
      [1, 2, 3, 4].each do |round|
        games = playoff_games.where(playoff_round: round)
        next if games.empty?
        round_name = NbaGame.playoff_round_name(round)
        watched = games.watched.count
        puts "    #{round_name}: #{games.count} games (#{watched} watched)"
      end
    end
    
    puts "\n📺 Viewing Habits:"
    puts "  By Network:"
    NbaGame.watched.group(:network).count.sort_by(&:last).reverse.first(5).each do |network, count|
      puts "    #{network || 'Unknown'}: #{count} games"
    end
    
    puts "\n  By Screen:"
    NbaGame.watched.group(:screen).count.sort_by(&:last).reverse.each do |screen, count|
      puts "    #{screen || 'Unknown'}: #{count} games"
    end
    
    puts "\n  By Place:"
    NbaGame.watched.group(:place).count.sort_by(&:last).reverse.each do |place, count|
      puts "    #{place || 'Unknown'}: #{count} games"
    end
    
    puts "\n🏀 Most Watched Teams:"
    team_watches = {}
    NbaTeam.find_each do |team|
      total = team.games_watched.count
      team_watches[team.display_name] = total if total > 0
    end
    
    team_watches.sort_by(&:last).reverse.first(10).each do |team_name, count|
      puts "  #{team_name}: #{count} games"
    end
    
    puts "=" * 50
  end
  
  desc "Fix team references (convert abbreviations to IDs if needed)"
  task fix_team_references: :environment do
    puts "Checking for any games with invalid team references..."
    
    invalid_games = NbaGame.includes(:home_team, :away_team)
                           .where(home_team: nil)
                           .or(NbaGame.where(away_team: nil))
    
    if invalid_games.any?
      puts "Found #{invalid_games.count} games with invalid team references"
      puts "You may need to import teams first or check your data"
    else
      puts "✅ All games have valid team references!"
    end
  end
end