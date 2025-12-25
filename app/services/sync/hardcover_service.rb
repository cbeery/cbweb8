# app/services/sync/hardcover_service.rb
require 'httparty'

module Sync
  class HardcoverService < BaseService
    include HTTParty
    base_uri 'https://api.hardcover.app/v1/graphql'
    
    DEFAULT_SYNC_MONTHS = 3
    
    # Status IDs from Hardcover API
    STATUS_WANT_TO_READ = 1
    STATUS_CURRENTLY_READING = 2
    STATUS_READ = 3
    STATUS_PAUSED = 4
    STATUS_DID_NOT_FINISH = 5
    STATUS_IGNORED = 6
    
    def initialize(sync_status: nil, broadcast: false, months_back: nil)
      super(sync_status: sync_status, broadcast: broadcast)
      @months_back = months_back || DEFAULT_SYNC_MONTHS
      
      begin
        @access_token = fetch_access_token
        validate_token!
      rescue => e
        log(:error, "Authentication setup failed: #{e.message}")
        if sync_status
          sync_status.update!(
            status: 'failed',
            error_message: e.message,
            completed_at: Time.current
          )
          broadcast_status if broadcast
        end
        raise
      end
    end
    
    protected
    
    def source_type
      'hardcover'
    end
    
    def fetch_items
      log(:info, "Starting Hardcover sync - fetching books from API")
      log(:info, "Sync window: last #{@months_back} months") if @months_back
      
      begin
        test_api_connection!
        
        # Fetch all user books
        all_books = fetch_all_user_books
        
        log(:info, "Found #{all_books.size} total books in library")
        
        # Filter by date if specified for read books
        if @months_back
          cutoff_date = @months_back.months.ago.to_date
          filtered_books = all_books.select do |book|
            # Keep all non-read books
            next true if book[:status_id] != STATUS_READ
            # Keep read books within the time window
            book[:finished_on] && book[:finished_on] >= cutoff_date
          end
          log(:info, "Filtered to #{filtered_books.size} books (last #{@months_back} months of read + all current)")
          filtered_books
        else
          all_books
        end
      rescue => e
        log(:error, "Failed to fetch items from Hardcover: #{e.message}")
        raise
      end
    end
    

    def process_item(book_data)
      log(:info, "Processing book: #{book_data[:title]}")
      
      begin
        # Find book using multiple strategies
        book = find_or_create_book_smart(book_data)
        
        is_new = book.new_record?
        was_missing_hardcover_id = book.hardcover_id.blank?
        
        # Update book attributes (without dates)
        book.assign_attributes(
          title: book_data[:title],
          author: book_data[:author],
          status: map_status(book_data[:status_id]),
          rating: book_data[:rating],
          progress: calculate_progress(book_data),
          isbn: book_data[:isbn] || book.isbn,           # Keep existing if not provided
          isbn13: book_data[:isbn13] || book.isbn13,     # Keep existing if not provided
          hardcover_id: book_data[:hardcover_id],         # Always update this
          series: book_data[:series] || book.series,
          series_position: book_data[:series_position] || book.series_position,
          page_count: book_data[:page_count] || book.page_count,
          published_year: book_data[:published_year] || book.published_year,
          publisher: book_data[:publisher] || book.publisher,
          description: book_data[:description] || book.description,
          times_read: [book_data[:times_read] || 1, book.times_read || 0].max,  # Take the higher value
          metadata: (book.metadata || {}).merge(book_data[:metadata] || {}),
          last_synced_at: Time.current
        )
        
        book.save!
        
        # Handle BookRead records based on status
        handle_book_reads(book, book_data) if defined?(BookRead)
        
        # Handle cover image if needed
        if book.should_sync_cover? && book_data[:cover_url].present?
          download_cover_image(book, book_data[:cover_url])
        end
        
        if is_new
          log(:success, "Created book: #{book.title}")
          :created
        elsif was_missing_hardcover_id
          log(:success, "Linked existing book to Hardcover: #{book.title}")
          :updated
        else
          log(:info, "Updated book: #{book.title}")
          :updated
        end
        
      rescue => e
        log(:error, "Failed to process book: #{e.message}", 
            book_title: book_data[:title],
            error: e.class.name)
        :failed
      end
    end

    def describe_item(book_data)
      "#{book_data[:title]} by #{book_data[:author]}"
    end
    
    private
    
    def fetch_access_token
      token = Rails.application.credentials.dig(:hardcover, :access_token) ||
              ENV['HARDCOVER_ACCESS_TOKEN']
      
      if token.blank?
        raise "Hardcover access token not configured. Please set HARDCOVER_ACCESS_TOKEN environment variable."
      end
      
      # Remove "Bearer " prefix if it exists
      token.sub(/^bearer\s+/i, '')
    end
    
    def validate_token!
      if @access_token.length < 10
        raise "Invalid Hardcover access token format"
      end
      
      log(:info, "Hardcover token found (#{@access_token[0..10]}...)")
    end
    
    def test_api_connection!
      log(:info, "Testing Hardcover API connection...")
      
      test_query = <<-GRAPHQL
        query {
          me {
            id
            username
            name
          }
        }
      GRAPHQL
      
      response = execute_query(test_query)
      
      # me returns an array
      user = response.dig('data', 'me', 0)
      
      if user.nil?
        raise "Failed to get user information from Hardcover API"
      end
      
      username = user['username'] || 'Unknown'
      log(:success, "Successfully connected to Hardcover API as user: #{username}")
    end
    
    def fetch_all_user_books
      log(:info, "Fetching all books from user library...")
      
      query = <<-GRAPHQL
        query {
          me {
            id
            user_books {
              book_id
              status_id
              rating
              review
              first_started_reading_date
              first_read_date
              last_read_date
              read_count
              book {
                id
                title
                subtitle
                description
                pages
                release_year
                release_date
                contributions {
                  author {
                    id
                    name
                  }
                }
                book_series {
                  series {
                    name
                  }
                  position
                }
                default_physical_edition {
                  isbn_10
                  isbn_13
                  publisher {
                    name
                  }
                }
                cached_image
              }
            }
          }
        }
      GRAPHQL
      
      response = execute_query(query)
      
      # Extract user_books from the response
      user = response.dig('data', 'me', 0)
      user_books = user['user_books'] || []
      
      log(:info, "Retrieved #{user_books.size} books from API")
      
      # Map to our internal structure
      user_books.map do |user_book|
        book = user_book['book'] || {}
        
        # Get first author name from contributions
        author_name = extract_author_name(book['contributions'])
        
        # Get series info from book_series
        series_info = extract_series_info(book['book_series'])
        
        # Get ISBN and publisher from default edition
        edition = book['default_physical_edition'] || {}
        isbn10 = edition['isbn_10']
        isbn13 = edition['isbn_13']
        publisher = edition.dig('publisher', 'name')
        
        # Get cover image URL
        cover_url = extract_cover_url(book['cached_image'])
        
        {
          hardcover_id: book['id']&.to_s,
          title: book['title'],
          author: author_name,
          status_id: user_book['status_id'],
          started_on: parse_date(user_book['first_started_reading_date']),
          finished_on: parse_date(user_book['first_read_date'] || user_book['last_read_date']),
          rating: user_book['rating']&.to_f,
          review: user_book['review'],
          times_read: user_book['read_count'] || 1,
          isbn: isbn10,
          isbn13: isbn13,
          page_count: book['pages'],
          published_year: book['release_year'] || parse_year_from_date(book['release_date']),
          publisher: publisher,
          description: truncate_description(book['description']),
          series: series_info[:name],
          series_position: series_info[:position],
          cover_url: cover_url,
          metadata: {
            book_id: user_book['book_id'],
            subtitle: book['subtitle'],
            cached_image: book['cached_image']
          }
        }
      end
    end
    
    def extract_author_name(contributions)
      return 'Unknown Author' unless contributions.is_a?(Array) && contributions.any?
      
      # Find the first author contribution
      author_contribution = contributions.find { |c| c['author'].present? }
      author_contribution&.dig('author', 'name') || 'Unknown Author'
    end
    
    def extract_series_info(book_series)
      return { name: nil, position: nil } unless book_series.is_a?(Array) && book_series.any?
      
      first_series = book_series.first
      {
        name: first_series&.dig('series', 'name'),
        position: first_series&.dig('position')
      }
    end
    
    def extract_cover_url(cached_image)
      return nil unless cached_image.present?
      
      # cached_image is a Hash with 'url' key
      if cached_image.is_a?(Hash)
        cached_image['url']
      elsif cached_image.is_a?(String)
        # Just in case it's sometimes a string
        cached_image
      else
        nil
      end
    end
    
    def parse_year_from_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string).year rescue nil
    end
    
    def map_status(status_id)
      case status_id
      when STATUS_WANT_TO_READ
        'want_to_read'
      when STATUS_CURRENTLY_READING
        'currently_reading'
      when STATUS_READ
        'read'
      when STATUS_PAUSED, STATUS_DID_NOT_FINISH
        'want_to_read' # Map paused/DNF to want_to_read
      else
        'want_to_read'
      end
    end
    
    def calculate_progress(book_data)
      # For currently reading books, calculate progress if we have page info
      if book_data[:status_id] == STATUS_CURRENTLY_READING && book_data[:page_count]
        # This would need additional API data if Hardcover tracks current page
        nil
      else
        nil
      end
    end
    
    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string) rescue nil
    end
    
    def truncate_description(description)
      return nil if description.blank?
      # Truncate very long descriptions
      description.length > 5000 ? description[0...5000] + '...' : description
    end
    
    def execute_query(query)
      log(:debug, "Executing GraphQL query...")
      
      begin
        response = self.class.post(
          '',
          headers: {
            'Authorization' => "Bearer #{@access_token}",
            'Content-Type' => 'application/json'
          },
          body: { query: query }.to_json,
          timeout: 30
        )
      rescue Net::ReadTimeout => e
        raise "Hardcover API request timed out after 30 seconds"
      rescue => e
        raise "Failed to connect to Hardcover API: #{e.message}"
      end
      
      unless response.success?
        raise "Hardcover API HTTP error: #{response.code}"
      end
      
      parsed_response = response.parsed_response
      
      if parsed_response['errors'].present?
        error_messages = parsed_response['errors'].map { |e| e['message'] }.join(', ')
        raise "Hardcover GraphQL errors: #{error_messages}"
      end
      
      parsed_response
    end
    
    def download_cover_image(book, cover_url)
      DownloadBookCoverJob.perform_later(book, cover_url)
    end

    def handle_book_reads(book, book_data)
      case book_data[:status_id]
      when STATUS_WANT_TO_READ
        # Don't create BookRead for want-to-read books
        log(:debug, "Book on want-to-read shelf, no BookRead created")
        
      when STATUS_CURRENTLY_READING
        # Find or create a current read
        book_read = book.book_reads
                        .in_progress
                        .first_or_initialize
        
        book_read.started_on ||= book_data[:started_on] || Date.current
        book_read.metadata = (book_read.metadata || {}).merge(
          hardcover_status: 'currently_reading',
          last_synced: Time.current
        )
        
        if book_read.save
          log(:debug, "Updated/created currently reading BookRead")
        end
        
      when STATUS_READ
        # Handle completed reads
        handle_completed_read(book, book_data)
        
      when STATUS_PAUSED, STATUS_DID_NOT_FINISH
        # These could be handled as incomplete reads if desired
        log(:debug, "Book paused/DNF, treating as want-to-read")
      end
    end
    
    def handle_completed_read(book, book_data)
      if book_data[:finished_on].present?
        # First, try to find an existing read by finished_on date
        book_read = book.book_reads.find_by(finished_on: book_data[:finished_on])

        # If not found, check for a read with missing finish date we can update
        book_read ||= book.book_reads.find_by(finished_on: nil)

        # If still not found, create a new one
        book_read ||= book.book_reads.new

        # Update the read details
        book_read.assign_attributes(
          finished_on: book_data[:finished_on],
          started_on: book_data[:started_on],
          rating: book_data[:rating],
          metadata: (book_read.metadata || {}).merge(
            hardcover_status: 'read',
            last_synced: Time.current,
            review: book_data[:review]
          )
        )

        if book_read.save
          log(:debug, "Updated/created completed BookRead for #{book_data[:finished_on]}")
        else
          log(:error, "Failed to save BookRead: #{book_read.errors.full_messages.join(', ')}")
        end
      else
        # No finish date but marked as read - create a basic read entry
        # Check if we already have any reads at all
        unless book.book_reads.exists?
          book_read = book.book_reads.create!(
            finished_on: nil,
            started_on: book_data[:started_on],
            rating: book_data[:rating],
            metadata: {
              hardcover_status: 'read',
              missing_finish_date: true,
              last_synced: Time.current
            }
          )
          log(:debug, "Created BookRead without finish date")
        end
      end
      
      # Handle multiple reads if times_read > current read count
      current_read_count = book.book_reads.completed.count
      if book_data[:times_read] && book_data[:times_read] > current_read_count
        log(:info, "Book has been read #{book_data[:times_read]} times but we only have #{current_read_count} reads recorded")
        # The Goodreads import will fill in the historical reads
      end
    end

    def find_or_create_book_smart(book_data)
      # Strategy 1: Find by hardcover_id (most specific)
      if book_data[:hardcover_id].present?
        book = Book.find_by(hardcover_id: book_data[:hardcover_id])
        if book
          log(:debug, "Found book by hardcover_id: #{book_data[:hardcover_id]}")
          return book
        end
      end
      
      # Strategy 2: Find by ISBN13 (very reliable)
      if book_data[:isbn13].present?
        book = Book.find_by(isbn13: book_data[:isbn13])
        if book
          log(:info, "Found book by ISBN13: #{book_data[:isbn13]} - will add hardcover_id")
          return book
        end
      end
      
      # Strategy 3: Find by ISBN (also reliable)
      if book_data[:isbn].present?
        book = Book.find_by(isbn: book_data[:isbn])
        if book
          log(:info, "Found book by ISBN: #{book_data[:isbn]} - will add hardcover_id")
          return book
        end
      end
      
      # Strategy 4: Find by exact title and author match
      # Clean up the title for matching (remove series info that might differ)
      clean_title = book_data[:title].gsub(/\s*\([^)]*\)\s*$/, '').strip
      
      book = Book.where('LOWER(title) = LOWER(?) OR LOWER(title) LIKE LOWER(?)', 
                         clean_title, 
                         "#{clean_title} (%")
                 .where('LOWER(author) = LOWER(?)', book_data[:author].downcase)
                 .first
      
      if book
        log(:info, "Found book by title/author match: #{book.title} - will add hardcover_id")
        return book
      end
      
      # Strategy 5: Fuzzy match on title (for slight variations)
      if book_data[:isbn13].blank? && book_data[:isbn].blank?
        # Only do fuzzy matching if we don't have ISBNs (to avoid false matches)
        similar_books = Book.where('LOWER(author) = LOWER(?)', book_data[:author].downcase)
        
        similar_books.each do |existing_book|
          # Calculate similarity (simple approach - you could use a gem like fuzzy_match)
          existing_title_clean = existing_book.title.gsub(/\s*\([^)]*\)\s*$/, '').strip.downcase
          new_title_clean = clean_title.downcase
          
          if similar_enough?(existing_title_clean, new_title_clean)
            log(:info, "Found book by fuzzy title match: #{existing_book.title} - will add hardcover_id")
            return existing_book
          end
        end
      end
      
      # No match found, create new book
      log(:info, "No existing book found, creating new record")
      Book.new
    end

    def similar_enough?(title1, title2)
      # Remove common words that might differ
      clean1 = title1.gsub(/\b(the|a|an)\b/i, '').gsub(/[^a-z0-9]+/, '').downcase
      clean2 = title2.gsub(/\b(the|a|an)\b/i, '').gsub(/[^a-z0-9]+/, '').downcase
      
      # Check if one contains the other (for subtitles)
      return true if clean1.include?(clean2) || clean2.include?(clean1)
      
      # Calculate Levenshtein distance (simple implementation)
      distance = levenshtein_distance(clean1, clean2)
      max_length = [clean1.length, clean2.length].max
      
      # Allow up to 10% difference
      similarity = 1.0 - (distance.to_f / max_length)
      similarity >= 0.90
    end

    def levenshtein_distance(s1, s2)
      # Simple Levenshtein distance calculation
      m = s1.length
      n = s2.length
      return m if n == 0
      return n if m == 0
      
      d = Array.new(m+1) { Array.new(n+1) }
      
      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }
      
      (1..n).each do |j|
        (1..m).each do |i|
          cost = s1[i-1] == s2[j-1] ? 0 : 1
          d[i][j] = [
            d[i-1][j] + 1,     # deletion
            d[i][j-1] + 1,     # insertion
            d[i-1][j-1] + cost # substitution
          ].min
        end
      end
      
      d[m][n]
    end

        
  end
end