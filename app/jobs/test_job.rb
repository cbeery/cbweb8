class TestJob < ApplicationJob
  queue_as :default

  def perform(message = "Default test message")
    Rails.logger.info "TestJob executing with message: #{message}"
    
    # Simulate some work
    sleep(2)
    
    # Log completion
    Rails.logger.info "TestJob completed at #{Time.current}"
    
    # You could add more complex logic here like:
    # - Sending an email
    # - Processing data
    # - Making API calls
    
    "Job completed successfully with message: #{message}"
  end
end