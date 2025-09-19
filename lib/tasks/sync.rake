# lib/tasks/sync.rake
namespace :sync do
  desc "Run a test sync job"
  task test: :environment do
    user = User.first
    
    scenario = 'slow'
    
    sync_status = SyncStatus.create!(
      source_type: 'test',
      interactive: false,
      user: user,
      metadata: { 
        scenario: scenario,
        triggered_by: user.email,
        test_run: true
      }
    )
        
    SyncJob.perform_later('Sync::TestService', sync_status.id, broadcast: false)
    
  end

  desc "Run sync with specific user (pass email as argument)"
  task :run, [:email] => :environment do |t, args|
    user = User.find_by!(email: args[:email])
    
    sync = SyncStatus.create!(
      name: "Manual Sync by #{user.name}",
      status: 'pending',
      user: user,
      interactive: true
    )
    
    YourSyncJob.perform_later(sync.id)
    puts "Queued sync ##{sync.id} for #{user.email}"
  end

  desc "Run sync in background (via SolidQueue)"
  task background: :environment do
    user = User.first
    sync = SyncStatus.create!(
      name: "Background Test Sync",
      status: 'pending',
      user: user,
      interactive: false  # Don't broadcast
    )
    
    YourSyncJob.perform_later(sync.id)
    puts "Queued sync ##{sync.id} to SolidQueue"
    puts "Run 'rails solid_queue:start' in another terminal to process"
  end

  desc "Clean up old test syncs"
  task cleanup: :environment do
    count = SyncStatus.where("name LIKE ?", "Test%")
                      .where("created_at < ?", 1.hour.ago)
                      .destroy_all.count
    puts "Deleted #{count} old test syncs"
  end
  
  desc "Show recent sync statuses"
  task status: :environment do
    SyncStatus.recent.limit(10).each do |sync|
      puts "#{sync.id.to_s.rjust(3)}: #{sync.name.ljust(30)} | #{sync.status.ljust(10)} | #{sync.created_at}"
    end
  end
end