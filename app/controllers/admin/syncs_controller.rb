# app/controllers/admin/syncs_controller.rb
class Admin::SyncsController < Admin::BaseController
  def index
    @sync_statuses = SyncStatus
      .includes(:log_entries)
      .order(created_at: :desc)
      .limit(20)
    @available_sources = sync_sources
  end
  
  def show
    @sync_status = SyncStatus.find(params[:id])
    @log_entries = @sync_status.log_entries.recent
  end
  
  def create
    source = params[:source]
    
    # Validate source
    unless sync_sources.include?(source)
      flash[:error] = "Invalid sync source: #{source}"
      redirect_to admin_syncs_path and return
    end
    
    # Special handling for test service
    if source == 'test'
      create_test_sync
    else
      create_normal_sync(source)
    end
  end
  
  private
  
  def sync_sources
    # Could be configuration-based
    %w[test letterboxd strava spotify lastfm swarm scrobble_plays]

  end
  
  def create_test_sync
    scenario = params[:scenario] || 'normal'
    
    sync_status = SyncStatus.create!(
      source_type: 'test',
      interactive: true,
      user: current_user,
      metadata: { 
        scenario: scenario,
        triggered_by: current_user.email,
        test_run: true
      }
    )
    
    LogEntry.sync(
      :info, 
      "Test sync triggered with '#{scenario}' scenario",
      sync_status: sync_status,
      user: current_user
    )
    
    SyncJob.perform_later('Sync::TestService', sync_status.id, broadcast: true)
    
    redirect_to admin_sync_path(sync_status)
  end
  
  def create_normal_sync(source)
    # Determine service class name
    service_class = "Sync::#{source.camelize}Service"
    
    # Validate service exists
    unless service_exists?(service_class)
      flash[:error] = "Sync service not implemented: #{source}"
      redirect_to admin_syncs_path and return
    end
    
    # Create sync status record
    sync_status = SyncStatus.create!(
      source_type: source,
      interactive: true,
      user: current_user,
      metadata: {
        triggered_by: current_user.email,
        manual_sync: true,
        triggered_at: Time.current.iso8601
      }
    )
    
    # Log the sync initiation
    LogEntry.sync(
      :info,
      "#{source.capitalize} sync triggered manually",
      sync_status: sync_status,
      user: current_user
    )
    
    # Enqueue the sync job with broadcast enabled for real-time updates
    SyncJob.perform_later(service_class, sync_status.id, broadcast: true)
    
    # Add success message
    flash[:success] = "#{source.capitalize} sync started successfully"
    
    # Redirect to the sync status page to monitor progress
    redirect_to admin_sync_path(sync_status)
    
  rescue StandardError => e
    Rails.logger.error "Failed to create sync for #{source}: #{e.message}"
    flash[:error] = "Failed to start sync: #{e.message}"
    redirect_to admin_syncs_path
  end
  
  def service_exists?(service_class)
    service_class.constantize
    true
  rescue NameError
    false
  end
end