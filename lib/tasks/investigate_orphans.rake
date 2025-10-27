namespace :bikes do
  desc "Investigate orphaned Strava ride activities without Ride records"
  task investigate_orphans: :environment do
    puts "\n=== Investigating Orphaned Strava Activities ==="
    
    # Find Strava ride activities without corresponding Ride records
    orphaned_activities = StravaActivity.rides
                                       .left_joins(:ride)
                                       .where(rides: { id: nil })
    
    puts "Found #{orphaned_activities.count} orphaned Strava ride activities\n\n"
    
    # Group by reason
    no_gear = orphaned_activities.where(gear_id: nil).count
    gear_not_found = orphaned_activities.where.not(gear_id: nil)
                                        .select { |a| !Bicycle.exists?(strava_gear_id: a.gear_id) }
                                        .count
    has_valid_gear = orphaned_activities.where.not(gear_id: nil)
                                        .select { |a| Bicycle.exists?(strava_gear_id: a.gear_id) }
    
    puts "Breakdown:"
    puts "  #{no_gear} activities have no gear_id (bike not specified in Strava)"
    puts "  #{gear_not_found} activities have gear_id not matching any bicycle"
    puts "  #{has_valid_gear.count} activities have valid gear but no Ride record (data issue)\n\n"
    
    if has_valid_gear.any?
      puts "Activities with valid gear but no Ride:"
      has_valid_gear.first(10).each do |activity|
        bicycle = Bicycle.find_by(strava_gear_id: activity.gear_id)
        puts "  - #{activity.name} on #{activity.started_at.to_date}"
        puts "    Strava ID: #{activity.strava_id}, Gear: #{bicycle.name}"
      end
      puts "  ... and #{has_valid_gear.count - 10} more" if has_valid_gear.count > 10
    end
    
    if gear_not_found > 0
      puts "\nUnique gear_ids not found in bicycles:"
      unknown_gears = orphaned_activities.where.not(gear_id: nil)
                                         .pluck(:gear_id)
                                         .uniq
                                         .reject { |g| Bicycle.exists?(strava_gear_id: g) }
      unknown_gears.each do |gear_id|
        count = orphaned_activities.where(gear_id: gear_id).count
        puts "  #{gear_id}: #{count} activities"
      end
    end
    
    puts "\n=== Investigation Complete ===\n"
  end
  
  desc "Create missing Ride records for orphaned Strava activities"
  task fix_orphans: :environment do
    puts "\n=== Creating Missing Ride Records ==="
    
    # Find orphaned activities that have valid gear
    orphaned_with_gear = StravaActivity.rides
                                       .left_joins(:ride)
                                       .where(rides: { id: nil })
                                       .where.not(gear_id: nil)
    
    created = 0
    skipped = 0
    
    orphaned_with_gear.find_each do |activity|
      bicycle = Bicycle.find_by(strava_gear_id: activity.gear_id)
      
      if bicycle.nil?
        skipped += 1
        next
      end
      
      # Check if a ride already exists for this date/bike combo (might be duplicate)
      existing = Ride.where(
        bicycle: bicycle,
        rode_on: activity.activity_date,
        strava_id: activity.strava_id
      ).first
      
      if existing
        # Just link them
        existing.update!(strava_activity_id: activity.id)
        print 'L'
      else
        # Create new ride
        ride = Ride.create!(
          bicycle: bicycle,
          strava_activity: activity,
          strava_id: activity.strava_id,
          rode_on: activity.activity_date,
          miles: activity.distance_in_miles,
          duration: activity.moving_time,
          notes: "Created from orphaned Strava activity: #{activity.name}"
        )
        created += 1
        print '.'
      end
    end
    
    puts "\n\nCreated #{created} new Ride records"
    puts "Skipped #{skipped} activities (no matching bicycle)"
    
    # Verify again
    remaining = StravaActivity.rides.left_joins(:ride).where(rides: { id: nil }).count
    puts "\nRemaining orphaned activities: #{remaining}"
    puts "=== Fix Complete ===\n"
  end
  
  desc "List bicycles and their Strava gear IDs"
  task list_gear: :environment do
    puts "\n=== Bicycles and Strava Gear IDs ==="
    puts "%-30s | %-15s | %s" % ["Bicycle Name", "Strava Gear ID", "Ride Count"]
    puts "-" * 65
    
    Bicycle.order(:name).each do |bike|
      strava_count = bike.rides.with_strava.count
      puts "%-30s | %-15s | %d (%d w/Strava)" % [
        bike.name.truncate(30),
        bike.strava_gear_id || "(none)",
        bike.rides.count,
        strava_count
      ]
    end
    
    puts "\n=== Gear IDs in Strava Activities ==="
    gear_counts = StravaActivity.rides
                                .group(:gear_id)
                                .count
                                .sort_by { |_, count| -count }
    
    gear_counts.each do |gear_id, count|
      bike = Bicycle.find_by(strava_gear_id: gear_id)
      status = bike ? "✓ #{bike.name}" : "✗ No matching bicycle"
      puts "#{gear_id || '(none)'}: #{count} activities - #{status}"
    end
    
    puts "=== Complete ===\n"
  end
end
