# app/jobs/download_book_cover_job.rb
class DownloadBookCoverJob < ApplicationJob
  queue_as :default
  
  def perform(book, cover_url)
    return if book.cover_manually_uploaded?
    return if book.cover_image.attached?
    
    begin
      response = HTTParty.get(cover_url)
      
      if response.success?
        filename = "book_cover_#{book.id}.jpg"
        
        book.cover_image.attach(
          io: StringIO.new(response.body),
          filename: filename,
          content_type: response.headers['content-type'] || 'image/jpeg'
        )
        
        Rails.logger.info "Downloaded cover for book ##{book.id}: #{book.title}"
      else
        Rails.logger.error "Failed to download cover from #{cover_url}: #{response.code}"
      end
    rescue => e
      Rails.logger.error "Error downloading book cover: #{e.message}"
    end
  end
end