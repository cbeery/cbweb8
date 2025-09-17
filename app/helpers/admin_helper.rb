# app/helpers/admin_helper.rb
module AdminHelper
  def status_color(status)
    case status
    when 'pending' then 'secondary'
    when 'running' then 'primary'
    when 'completed' then 'success'
    when 'failed' then 'danger'
    else 'secondary'
    end
  end
  
  def progress_percentage(sync_status)
    sync_status.progress_percentage
  end
  
  def log_level_class(level)
    case level
    when 'success' then 'text-success'
    when 'warning' then 'text-warning' 
    when 'error' then 'text-danger'
    when 'debug' then 'text-muted'
    else 'text-info'
    end
  end
  
  def log_level_icon(level)
    case level
    when 'success' then '✓'
    when 'warning' then '⚠'
    when 'error' then '✗'
    when 'debug' then '🔍'
    else 'ℹ'
    end
  end
end