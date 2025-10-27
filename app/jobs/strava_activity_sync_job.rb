# app/jobs/strava_activity_sync_job.rb
class StravaActivitySyncJob < ApplicationJob
  queue_as :default
  
  def perform(sync_status_id = nil, days_back: 7, broadcast: false)
    Rails.logger.info "Starting Strava activity sync job"
    
    # Create or use existing sync status
    sync_status = if sync_status_id
      SyncStatus.find(sync_status_id)
    else
      SyncStatus.create!(
        source_type: 'strava',
        interactive: false,
        metadata: {
          scheduled: true,
          days_back: days_back,
          started_at: Time.current.iso8601
        }
      )
    end
    
    # Initialize and run the sync service
    service = Sync::StravaActivityService.new(
      sync_status: sync_status,
      broadcast: broadcast,
      days_back: days_back
    )
    
    service.perform
    
    Rails.logger.info "Strava activity sync job completed"
  rescue => e
    Rails.logger.error "Strava sync job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    if sync_status
      sync_status.update!(
        status: 'failed',
        error_message: e.message,
        completed_at: Time.current
      )
    end
    
    raise
  end
end
