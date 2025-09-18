# app/models/sync_status.rb
class SyncStatus < ApplicationRecord
  has_many :log_entries, as: :loggable, dependent: :destroy
  
  scope :recent, -> { where(created_at: 1.day.ago..).order(created_at: :desc) }
  scope :interactive, -> { where(interactive: true) }
  
  def pending?
    status == 'pending'
  end
  
  def running?
    status == 'running'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def has_progress?
    total_items.present? && total_items > 0
  end
  
  def progress_percentage
    return 0 unless has_progress?
    return 100 if completed?
    [(processed_items.to_f / total_items * 100).round, 99].min
  end
  
  def should_broadcast?
    interactive? && created_at > 1.hour.ago
  end

  def log(level, message, **data)
    entry = LogEntry.sync(level, message, sync_status: self, **data)
    broadcast_log_entry(entry) if interactive?
    entry
  end
  
  # Helper methods for metadata access
  def last_sync_date
    metadata['last_entry_date']&.to_datetime
  end
  
  def incremental_sync_possible?
    metadata['last_entry_guid'].present? || metadata['last_entry_date'].present?
  end

  private

  def broadcast_log_entry(entry)
    Turbo::StreamsChannel.broadcast_append_to(
      "sync_status_#{id}_logs",
      target: "sync_log_entries",
      partial: "admin/syncs/log_entry",
      locals: { log_entry: entry }
    )
  end
end