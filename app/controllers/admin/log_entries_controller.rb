class Admin::LogEntriesController < Admin::BaseController
  def index
    @logs = LogEntry.includes(:loggable, :user)
    
    # Filtering
    @logs = @logs.by_category(params[:category]) if params[:category].present?
    @logs = @logs.where(level: params[:level]) if params[:level].present?
    @logs = @logs.where(created_at: date_range) if params[:date_from].present?
    
    @logs = @logs.recent.page(params[:page])
    
    @categories = LogEntry.distinct.pluck(:category).sort
    @levels = %w[debug info success warning error]
  end
  
  def show
    @log_entry = LogEntry.find(params[:id])
  end
  
  private
  
  def date_range
    from = Date.parse(params[:date_from]) rescue 1.week.ago
    to = params[:date_to].present? ? Date.parse(params[:date_to]) : Date.current
    from.beginning_of_day..to.end_of_day
  end
end