# app/models/log_entry.rb
class LogEntry < ApplicationRecord
  belongs_to :loggable, polymorphic: true, optional: true
  belongs_to :user, optional: true
  
  # Scopes for filtering
  scope :for_sync, ->(sync_status) { where(loggable: sync_status) }
  scope :by_category, ->(category) { where(category: category) }
  scope :recent, -> { order(created_at: :desc) }
  scope :errors, -> { where(level: 'error') }
  scope :today, -> { where(created_at: Time.current.beginning_of_day..) }
  
  # Quick creation methods
  def self.log(category, level, message, loggable: nil, user: nil, event: nil, **data)
    create!(
      category: category,
      level: level,
      message: message,
      event: event,
      loggable: loggable,
      user: user,
      data: data
    )
  end
  
  def self.sync(level, message, sync_status:, **data)
    log('sync', level, message, loggable: sync_status, **data)
  end
  
  def self.auth(level, message, user: nil, **data)
    log('auth', level, message, user: user, **data)
  end
  
  def self.system(level, message, **data)
    log('system', level, message, **data)
  end
  
  # Display helpers
  def level_class
    case level
    when 'success' then 'text-success'
    when 'warning' then 'text-warning' 
    when 'error' then 'text-danger'
    when 'debug' then 'text-muted'
    else 'text-info'
    end
  end
  
  def icon
    case level
    when 'success' then '✓'
    when 'warning' then '⚠'
    when 'error' then '✗'
    when 'debug' then '🔍'
    else 'ℹ'
    end
  end
  
  # Helper to access error details
  def error_details
    return nil unless level == 'error'
    OpenStruct.new(data)
  end
end