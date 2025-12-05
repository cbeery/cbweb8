# app/jobs/scheduled_scrobble_plays_sync_job.rb
class ScheduledScrobblePlaysSyncJob < ApplicationJob
  queue_as :default

  # This job is meant to be run weekly to sync Last.fm weekly chart data
  def perform
    Rails.logger.info "Starting scheduled Scrobble Plays sync at #{Time.current}"

    sync_status = SyncStatus.create!(
      source_type: 'lastfm',
      status: 'in_progress',
      interactive: false,
      metadata: {
        triggered_by: 'scheduled_job',
        started_at: Time.current.iso8601
      }
    )

    service = Sync::ScrobblePlaysService.new(
      sync_status: sync_status,
      broadcast: false
    )

    service.perform

    sync_status.reload

    Rails.logger.info "Scheduled Scrobble Plays sync completed: " \
                      "Created: #{sync_status.created_count}, " \
                      "Updated: #{sync_status.updated_count}"
  rescue => e
    Rails.logger.error "Scheduled Scrobble Plays sync failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise
  end
end
