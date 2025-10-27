namespace :import do
  desc "Import bikes and related data from legacy CSV files"
  task bikes_full: :environment do
    puts "Starting full bike data import..."
    
    # Import in proper order to maintain foreign key relationships
    Rake::Task["import:bicycles"].invoke
    Rake::Task["import:strava_activities"].invoke
    Rake::Task["import:rides"].invoke
    Rake::Task["import:milestones"].invoke
    
    puts "Full bike data import completed!"
  end
  
  desc "Import bicycles from CSV"
  task bicycles: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'bicycles.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing bicycles..."
    success_count = 0
    error_count = 0
    
    CSV.foreach(file_path, headers: true) do |row|
      begin
        bicycle = Bicycle.find_or_initialize_by(id: row['id'])
        
        bicycle.assign_attributes(
          name: row['name'],
          notes: row['notes'],
          active: row['active'].to_s.downcase == 'true',
          strava_gear_id: row['strava_gear_id'].presence,
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        )
        
        # Preserve the original ID for maintaining associations
        bicycle.id = row['id'] if row['id'].present?
        
        if bicycle.save!
          success_count += 1
          print '.'
        end
      rescue => e
        error_count += 1
        puts "\nError importing bicycle ID #{row['id']}: #{e.message}"
      end
    end
    
    puts "\nBicycles import completed: #{success_count} successful, #{error_count} errors"
    
    # Reset sequence to ensure new records don't conflict
    ActiveRecord::Base.connection.reset_pk_sequence!('bicycles')
  end
  
  desc "Import Strava activities from CSV"
  task strava_activities: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'strava_activities.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing Strava activities..."
    success_count = 0
    error_count = 0
    
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        activity = StravaActivity.find_or_initialize_by(id: row['id'])
        
        activity.assign_attributes(
          name: row['name'],
          strava_id: row['strava_id'],
          started_at: row['started_at'],
          ended_at: row['ended_at'],
          moving_time: row['moving_time'].to_i,
          elapsed_time: row['elapsed_time'].to_i,
          distance: row['distance'].to_f,
          distance_in_miles: row['distance_in_miles'].to_f,
          activity_type: row['activity_type'],
          commute: row['commute'].to_s.downcase == 'true',
          gear_id: row['gear_id'].presence,
          city: row['city'].presence,
          state: row['state'].presence,
          private: row['private'].to_s.downcase == 'true',
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        )
        
        # Preserve the original ID
        activity.id = row['id'] if row['id'].present?
        
        # Skip callback for ended_at and distance_in_miles since we're importing calculated values
        activity.save!(validate: false) if row['ended_at'].present? && row['distance_in_miles'].present?
        activity.save! unless row['ended_at'].present? && row['distance_in_miles'].present?
        
        success_count += 1
        print '.'
      rescue => e
        error_count += 1
        puts "\nError importing Strava activity ID #{row['id']}: #{e.message}"
      end
    end
    
    puts "\nStrava activities import completed: #{success_count} successful, #{error_count} errors"
    
    # Reset sequence
    ActiveRecord::Base.connection.reset_pk_sequence!('strava_activities')
  end
  
  desc "Import rides from CSV"
  task rides: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'rides.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing rides..."
    success_count = 0
    error_count = 0
    legacy_count = 0
    
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        ride = Ride.find_or_initialize_by(id: row['id'])
        
        # Check if this is a legacy ride (no Strava data)
        is_legacy = row['strava_activity_id'].blank? && row['strava_id'].blank?
        legacy_count += 1 if is_legacy
        
        ride.assign_attributes(
          bicycle_id: row['bicycle_id'],
          strava_activity_id: row['strava_activity_id'].presence,
          rode_on: row['rode_on'],
          miles: row['miles'].to_f,
          duration: row['duration'].to_i,  # Assuming this is already in seconds
          notes: row['notes'].presence,
          strava_id: row['strava_id'].presence,
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        )
        
        # Preserve the original ID
        ride.id = row['id'] if row['id'].present?
        
        if ride.save!
          success_count += 1
          print is_legacy ? 'L' : '.'
        end
      rescue => e
        error_count += 1
        puts "\nError importing ride ID #{row['id']}: #{e.message}"
        puts "  Bicycle ID: #{row['bicycle_id']}, Strava Activity ID: #{row['strava_activity_id']}"
      end
    end
    
    puts "\nRides import completed: #{success_count} successful (#{legacy_count} legacy), #{error_count} errors"
    
    # Reset sequence
    ActiveRecord::Base.connection.reset_pk_sequence!('rides')
  end
  
  desc "Import milestones from CSV"
  task milestones: :environment do
    require 'csv'
    
    file_path = Rails.root.join('tmp', 'import', 'milestones.csv')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      next
    end
    
    puts "Importing milestones..."
    success_count = 0
    error_count = 0
    
    CSV.foreach(file_path, headers: true, liberal_parsing: true) do |row|
      begin
        milestone = Milestone.find_or_initialize_by(id: row['id'])
        
        milestone.assign_attributes(
          bicycle_id: row['bicycle_id'],
          occurred_on: row['occurred_on'],
          title: row['title'],
          description: row['description'].presence,
          created_at: row['created_at'].presence || Time.current,
          updated_at: row['updated_at'].presence || Time.current
        )
        
        # Preserve the original ID
        milestone.id = row['id'] if row['id'].present?
        
        if milestone.save!
          success_count += 1
          print milestone.maintenance? ? 'M' : '.'
        end
      rescue => e
        error_count += 1
        puts "\nError importing milestone ID #{row['id']}: #{e.message}"
      end
    end
    
    puts "\nMilestones import completed: #{success_count} successful, #{error_count} errors"
    
    # Reset sequence
    ActiveRecord::Base.connection.reset_pk_sequence!('milestones')
  end
  
  desc "Verify imported bike data integrity"
  task verify_bikes: :environment do
    puts "\n=== Bike Data Verification ==="
    
    puts "\nBicycles: #{Bicycle.count}"
    Bicycle.all.each do |bike|
      puts "  #{bike.name}: #{bike.rides.count} rides, #{bike.milestones.count} milestones, #{bike.total_miles} miles"
    end
    
    puts "\nStrava Activities: #{StravaActivity.count}"
    puts "  Ride activities: #{StravaActivity.rides.count}"
    puts "  With gear: #{StravaActivity.with_gear.count}"
    puts "  Commutes: #{StravaActivity.commutes.count}"
    
    puts "\nRides: #{Ride.count}"
    puts "  With Strava: #{Ride.with_strava.count}"
    puts "  Legacy (without Strava): #{Ride.without_strava.count}"
    puts "  Total miles: #{Ride.sum(:miles).round(2)}"
    puts "  Total hours: #{(Ride.sum(:duration) / 3600.0).round(2)}"
    
    puts "\nMilestones: #{Milestone.count}"
    puts "  Maintenance: #{Milestone.all.select(&:maintenance?).count}"
    
    # Check for orphaned records
    orphaned_rides = Ride.where.not(strava_activity_id: nil)
                         .where.not(strava_activity_id: StravaActivity.select(:id))
    if orphaned_rides.any?
      puts "\n⚠️  Found #{orphaned_rides.count} rides with invalid strava_activity_id references"
    end
    
    # Check for Strava activities without rides
    activities_without_rides = StravaActivity.rides.left_joins(:ride).where(rides: { id: nil })
    if activities_without_rides.any?
      puts "\n⚠️  Found #{activities_without_rides.count} Strava ride activities without corresponding Ride records"
    end
    
    puts "\n=== Verification Complete ==="
  end
end
