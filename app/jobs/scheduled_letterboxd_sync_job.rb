# app/jobs/scheduled_letterboxd_sync_job.rb
class ScheduledLetterboxdSyncJob < ApplicationJob
  queue_as :default

  # This job is meant to be run nightly to sync Letterboxd RSS feed
  def perform
    Rails.logger.info "Starting scheduled Letterboxd sync at #{Time.current}"

    sync_status = SyncStatus.create!(
      source_type: 'letterboxd',
      status: 'in_progress',
      interactive: false,
      metadata: {
        triggered_by: 'scheduled_job',
        started_at: Time.current.iso8601
      }
    )

    service = Sync::LetterboxdService.new(
      sync_status: sync_status,
      broadcast: false
    )

    service.perform

    sync_status.reload

    Rails.logger.info "Scheduled Letterboxd sync completed: " \
                      "Created: #{sync_status.created_count}, " \
                      "Updated: #{sync_status.updated_count}, " \
                      "Skipped: #{sync_status.skipped_count}"
  rescue => e
    Rails.logger.error "Scheduled Letterboxd sync failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise
  end
end
