# app/jobs/scheduled_top_scrobbles_sync_job.rb
class ScheduledTopScrobblesSyncJob < ApplicationJob
  queue_as :default

  # This job is meant to be run nightly to sync Last.fm top charts
  def perform
    Rails.logger.info "Starting scheduled Top Scrobbles sync at #{Time.current}"

    sync_status = SyncStatus.create!(
      source_type: 'lastfm_top',
      status: 'in_progress',
      interactive: false,
      metadata: {
        triggered_by: 'scheduled_job',
        started_at: Time.current.iso8601
      }
    )

    service = Sync::TopScrobblesService.new(
      sync_status: sync_status,
      broadcast: false
    )

    service.perform

    sync_status.reload

    Rails.logger.info "Scheduled Top Scrobbles sync completed: " \
                      "Created: #{sync_status.created_count}, " \
                      "Updated: #{sync_status.updated_count}"
  rescue => e
    Rails.logger.error "Scheduled Top Scrobbles sync failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise
  end
end
