# app/jobs/spotify_single_sync_job.rb
class SpotifySingleSyncJob < ApplicationJob
  queue_as :default

  def perform(playlist_id, sync_status_id = nil)
    playlist = SpotifyPlaylist.find(playlist_id)
    sync_status = sync_status_id ? SyncStatus.find(sync_status_id) : nil
    
    # Use the single playlist sync service
    Sync::SpotifySingleService.new(
      playlist: playlist,
      sync_status: sync_status,
      broadcast: sync_status&.interactive? || false
    ).perform
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "SpotifySingleSyncJob failed: #{e.message}"
    sync_status&.update!(
      status: 'failed',
      error_message: "Playlist not found: #{e.message}",
      completed_at: Time.current
    )
    raise
  end
end
