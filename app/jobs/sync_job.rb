# app/jobs/sync_job.rb
class SyncJob < ApplicationJob
  queue_as :default

  def perform(service_class_name, sync_status_id = nil, broadcast: false)
    service_class = service_class_name.constantize
    sync_status = sync_status_id ? SyncStatus.find(sync_status_id) : nil
    
    service_class.new(
      sync_status: sync_status, 
      broadcast: broadcast
    ).perform
  end
end
