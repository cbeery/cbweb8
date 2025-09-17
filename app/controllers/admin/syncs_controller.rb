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
    %w[test letterboxd strava spotify lastfm]
  end
  
  def create_test_sync
    scenario = params[:scenario] || 'normal'
    
    sync_status = SyncStatus.create!(
      source_type: 'test',
      interactive: true,
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
  