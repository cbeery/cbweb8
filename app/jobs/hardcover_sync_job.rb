# app/jobs/hardcover_sync_job.rb
class HardcoverSyncJob < ApplicationJob
  queue_as :default
  
  def perform(sync_status_id, months_back = 3)
    sync_status = SyncStatus.find(sync_status_id)
    
    service = Sync::HardcoverService.new(
      sync_status: sync_status,
      broadcast: true,
      months_back: months_back
    )
    
    service.perform
  end
end