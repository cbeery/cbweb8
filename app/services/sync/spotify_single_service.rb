# app/services/sync/spotify_single_service.rb
module Sync
  class SpotifySingleService < SpotifyService
    attr_reader :playlist
    
    def initialize(playlist:, sync_status: nil, broadcast: false)
      @playlist = playlist
      super(sync_status: sync_status, broadcast: broadcast)
    end
    
    protected
    
    def source_type
      'spotify_single'
    end
    
    def fetch_items
      # Return just the single playlist as an array
      [@playlist]
    end
    
    def process_item(playlist)
      log(:info, "Syncing single playlist: #{playlist.name}")
      
      # Force the sync regardless of last_synced_at since user explicitly requested it
      ensure_authenticated!
      
      # Fetch playlist details from Spotify
      playlist_data = fetch_playlist_details(playlist.spotify_id)
      if playlist_data.nil?
        log(:error, "Could not fetch playlist data", playlist_id: playlist.id)
        return :failed
      end
      
      # Check if changed (for logging purposes)
      new_snapshot_id = playlist_data['snapshot_id']
      if playlist.snapshot_id.present? && playlist.snapshot_id == new_snapshot_id
        log(:info, "Playlist unchanged but syncing anyway (manual sync)", 
            playlist_id: playlist.id,
            snapshot_id: new_snapshot_id)
      else
        log(:info, "Playlist has changes, syncing", 
            playlist_id: playlist.id,
            old_snapshot: playlist.snapshot_id,
            new_snapshot: new_snapshot_id)
      end
      
      # Update playlist metadata
      update_playlist_metadata(playlist, playlist_data)
      
      # Fetch and sync all tracks
      sync_playlist_tracks(playlist, playlist_data)
      
      # Update calculated fields
      playlist.calculate_runtime!
      playlist.update!(last_synced_at: Time.current)
      
      :updated
    rescue => e
      log(:error, "Failed to sync playlist: #{e.message}", 
          playlist_id: playlist.id, 
          error: e.class.name)
      :failed
    end
    
    private
    
    # Override complete_sync to provide better messaging for single playlist
    def complete_sync
      sync_status.update!(
        status: 'completed',
        completed_at: Time.current
      )
      
      log(:info, "Successfully synced #{playlist.name}")
      broadcast_status if broadcast_enabled
    end
    
    # Override fail_sync to provide better error handling for single playlist
    def fail_sync(error)
      sync_status.update!(
        status: 'failed',
        error_message: error.message,
        completed_at: Time.current
      )
      
      log(:error, "Failed to sync #{playlist.name}: #{error.message}")
      broadcast_status if broadcast_enabled
    end
  end
end
