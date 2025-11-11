# app/jobs/scheduled_hardcover_sync_job.rb
class ScheduledHardcoverSyncJob < ApplicationJob
  queue_as :default
  
  # This job is meant to be run nightly to sync recent Hardcover data
  def perform
    Rails.logger.info "Starting scheduled Hardcover sync at #{Time.current}"
    
    sync_status = SyncStatus.create!(
      source_type: 'hardcover',
      status: 'in_progress',
      interactive: false,
      metadata: {
        triggered_by: 'scheduled_job',
        started_at: Time.current.iso8601
      }
    )
    
    service = Sync::HardcoverService.new(
      sync_status: sync_status,
      broadcast: false,
      months_back: 1 # Just sync the last month for nightly updates
    )
    
    service.perform
    
    sync_status.reload
    
    Rails.logger.info "Scheduled Hardcover sync completed: " \
                      "Created: #{sync_status.created_count}, " \
                      "Updated: #{sync_status.updated_count}, " \
                      "Failed: #{sync_status.failed_count}"
    
    # Send notification if there were failures
    if sync_status.failed_count > 0
      Rails.logger.error "Hardcover sync had #{sync_status.failed_count} failures"
      # You could send an email or other notification here
    end
  rescue => e
    Rails.logger.error "Scheduled Hardcover sync failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
    # Re-raise to let the job framework handle retries
    raise
  end
end

# For scheduling with Solid Queue, add to config/recurring.yml:
# hardcover_sync:
#   class: ScheduledHardcoverSyncJob
#   schedule: "every day at 2am"
#
# Or with whenever gem, add to config/schedule.rb:
# every 1.day, at: '2:00 am' do
#   runner "ScheduledHardcoverSyncJob.perform_later"
# end
