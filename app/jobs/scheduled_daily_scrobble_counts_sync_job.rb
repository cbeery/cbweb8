# app/jobs/scheduled_daily_scrobble_counts_sync_job.rb
class ScheduledDailyScrobbleCountsSyncJob < ApplicationJob
  queue_as :default

  # This job is meant to be run nightly to sync Last.fm daily play counts
  def perform
    Rails.logger.info "Starting scheduled Daily Scrobble Counts sync at #{Time.current}"

    sync_status = SyncStatus.create!(
      source_type: 'lastfm_daily',
      status: 'in_progress',
      interactive: false,
      metadata: {
        triggered_by: 'scheduled_job',
        started_at: Time.current.iso8601
      }
    )

    service = Sync::DailyScrobbleCountsService.new(
      sync_status: sync_status,
      broadcast: false
    )

    service.perform

    sync_status.reload

    Rails.logger.info "Scheduled Daily Scrobble Counts sync completed: " \
                      "Created: #{sync_status.created_count}, " \
                      "Updated: #{sync_status.updated_count}"
  rescue => e
    Rails.logger.error "Scheduled Daily Scrobble Counts sync failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise
  end
end
