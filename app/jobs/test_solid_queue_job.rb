class TestSolidQueueJob < ApplicationJob
  queue_as :default

  def perform(message = "Hello from SolidQueue!")
    Rails.logger.info "TestSolidQueueJob started at #{Time.current}"
    Rails.logger.info "Message: #{message}"
    
    # Add a small delay to make it visible in Mission Control
    sleep(5)
    
    Rails.logger.info "TestSolidQueueJob completed at #{Time.current}"
    puts "✅ Job completed successfully: #{message}"
  end
end
