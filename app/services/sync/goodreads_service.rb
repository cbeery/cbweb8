# app/services/sync/goodreads_service.rb
require 'httparty'
require 'nokogiri'

module Sync
  class GoodreadsService < BaseService
    include HTTParty
    base_uri 'https://www.goodreads.com'
    
    MAX_BOOKS_PER_REQUEST = 200 # Goodreads API limit
    
    def initialize(sync_status: nil, broadcast: false, shelf: 'read')
      super(sync_status: sync_status, broadcast: broadcast)
      @shelf = shelf
      @api_key = fetch_api_key
      @user_id = fetch_user_id
      
      validate_credentials!
    end
    
    protected
    
    def source_type
      'goodreads'
    end
    
    def fetch_items
      log(:info, "Starting Goodreads sync - fetching books from '#{@shelf}' shelf")
      
      all_books = []
      page = 1
      total_pages = nil
      
      loop do
        log(:info, "Fetching page #{page}#{total_pages ? " of #{total_pages}" : ""}")
        
        response = fetch_shelf_page(page)
        
        # Parse the XML response
        doc = Nokogiri::XML(response.body)
        
        # Get pagination info on first request
        if total_pages.nil?
          total_books = doc.at_xpath('//reviews/@total')&.value&.to_i || 0
          total_pages = (total_books.to_f / MAX_BOOKS_PER_REQUEST).ceil
          log(:info, "Found #{total_books} total books on #{@shelf} shelf")
        end
        
        # Extract book data from this page
        reviews = doc.xpath('//reviews/review')
        break if reviews.empty?
        
        reviews.each do |review|
          book_data = parse_review(review)
          all_books << book_data if book_data
        end
        
        # Check if we've fetched all pages
        break if page >= total_pages
        page += 1
        
        # Be nice to the API
        sleep 1
      end
      
      log(:info, "Fetched #{all_books.size} books from Goodreads")
      all_books
    end
    
    def process_item(book_data)
      log(:info, "Processing book: #{book_data[:title]}")
      
      begin
        # Find book by Goodreads ID first, then by title/author
        book = find_or_create_book(book_data)
        
        # Create BookRead record if this is from the read shelf
        if @shelf == 'read' && book_data[:read_at].present?
          create_or_update_book_read(book, book_data)
        elsif @shelf == 'currently-reading' && book_data[:started_at].present?
          # Handle currently reading books
          book_read = book.book_reads.in_progress.first_or_initialize
          book_read.started_on = book_data[:started_at]
          book_read.metadata = {
            goodreads_id: book_data[:review_id],
            imported_at: Time.current
          }
          book_read.save!
          book.update!(status: 'currently_reading')
        end
        
        # Download cover if available and not already present
        if book.should_sync_cover? && book_data[:image_url].present?
          download_cover_image(book, book_data[:image_url])
        end
        
        log(:success, "Processed: #{book.title}")
        :created
        
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
    
    def fetch_api_key
      key = Rails.application.credentials.dig(:goodreads, :api_key) ||
            ENV['GOODREADS_API_KEY']
      
      if key.blank?
        raise "Goodreads API key not configured. Please set GOODREADS_API_KEY environment variable."
      end
      
      key
    end
    
    def fetch_user_id
      user_id = Rails.application.credentials.dig(:goodreads, :user_id) ||
                ENV['GOODREADS_USER_ID']
      
      if user_id.blank?
        raise "Goodreads user ID not configured. Please set GOODREADS_USER_ID environment variable."
      end
      
      user_id
    end
    
    def validate_credentials!
      log(:info, "Validating Goodreads credentials...")
      log(:info, "API Key: #{@api_key[0..10]}...")
      log(:info, "User ID: #{@user_id}")
      
      # Test the API connection
      test_api_connection!
    end
    
    def test_api_connection!
      response = self.class.get(
        "/review/list/#{@user_id}.xml",
        query: {
          key: @api_key,
          v: 2,
          shelf: @shelf,
          per_page: 1
        }
      )
      
      unless response.success?
        raise "Failed to connect to Goodreads API: #{response.code} - #{response.message}"
      end
      
      log(:success, "Successfully connected to Goodreads API")
    end
    
    def fetch_shelf_page(page)
      self.class.get(
        "/review/list/#{@user_id}.xml",
        query: {
          key: @api_key,
          v: 2,
          shelf: @shelf,
          page: page,
          per_page: MAX_BOOKS_PER_REQUEST,
          sort: 'date_read'
        }
      )
    end
    
    def parse_review(review_node)
      book_node = review_node.at_xpath('book')
      return nil unless book_node
      
      {
        # Review data
        review_id: review_node.at_xpath('id')&.text,
        rating: review_node.at_xpath('rating')&.text&.to_i,
        read_at: parse_date(review_node.at_xpath('read_at')&.text),
        started_at: parse_date(review_node.at_xpath('started_at')&.text),
        date_added: parse_date(review_node.at_xpath('date_added')&.text),
        read_count: review_node.at_xpath('read_count')&.text&.to_i || 1,
        
        # Book data
        goodreads_id: book_node.at_xpath('id')&.text,
        title: book_node.at_xpath('title')&.text || 'Unknown Title',
        author: extract_author_name(book_node),
        isbn: book_node.at_xpath('isbn')&.text,
        isbn13: book_node.at_xpath('isbn13')&.text,
        page_count: book_node.at_xpath('num_pages')&.text&.to_i,
        published_year: book_node.at_xpath('publication_year')&.text&.to_i,
        publisher: book_node.at_xpath('publisher')&.text,
        description: clean_description(book_node.at_xpath('description')&.text),
        image_url: book_node.at_xpath('image_url')&.text,
        
        # Series info (if available)
        series_name: extract_series_name(book_node),
        series_position: extract_series_position(book_node)
      }
    end
    
    def extract_author_name(book_node)
      # Goodreads can have multiple authors
      authors = book_node.xpath('authors/author/name').map(&:text)
      authors.join(', ').presence || 'Unknown Author'
    end
    
    def extract_series_name(book_node)
      # Series info might be in the title or a separate field
      work_node = book_node.at_xpath('work')
      return nil unless work_node
      
      # Try to extract from title (common pattern: "Series Name (Series Name #1)")
      title = book_node.at_xpath('title')&.text
      if title =~ /\(([^#]+)\s*#/
        $1.strip
      else
        nil
      end
    end
    
    def extract_series_position(book_node)
      title = book_node.at_xpath('title')&.text
      if title =~ /#(\d+)/
        $1.to_i
      else
        nil
      end
    end
    
    def clean_description(description)
      return nil if description.blank?
      
      # Remove CDATA markers and clean up HTML
      description = description.gsub(/<!\[CDATA\[|\]\]>/, '')
      
      # Convert to plain text (remove HTML tags)
      doc = Nokogiri::HTML::DocumentFragment.parse(description)
      text = doc.text.strip
      
      # Truncate if too long
      text.length > 5000 ? text[0...5000] + '...' : text
    end
    
    def parse_date(date_string)
      return nil if date_string.blank?
      
      # Goodreads dates can be in various formats
      # Try parsing as a full date-time first
      Time.parse(date_string).to_date
    rescue
      # Try other formats
      begin
        Date.parse(date_string)
      rescue
        nil
      end
    end
    
    def find_or_create_book(book_data)
      # Strategy 1: Find by Goodreads ID (most specific)
      if book_data[:goodreads_id].present?
        book = Book.find_by(goodreads_id: book_data[:goodreads_id])
        if book
          log(:debug, "Found book by goodreads_id: #{book_data[:goodreads_id]}")
          return update_book_attributes(book, book_data)
        end
      end
      
      # Strategy 2: Find by ISBN13 (very reliable)
      if book_data[:isbn13].present?
        book = Book.find_by(isbn13: book_data[:isbn13])
        if book
          log(:info, "Found book by ISBN13: #{book_data[:isbn13]} - will add goodreads_id")
          return update_book_attributes(book, book_data)
        end
      end
      
      # Strategy 3: Find by ISBN (also reliable)
      if book_data[:isbn].present?
        book = Book.find_by(isbn: book_data[:isbn])
        if book
          log(:info, "Found book by ISBN: #{book_data[:isbn]} - will add goodreads_id")
          return update_book_attributes(book, book_data)
        end
      end
      
      # Strategy 4: Find by title and author
      # Clean the title - Goodreads often includes series in parentheses
      clean_title = book_data[:title].gsub(/\s*\([^)]*\)\s*$/, '').strip
      
      # Try exact match first
      book = Book.where('LOWER(title) = LOWER(?) OR LOWER(title) = LOWER(?) OR LOWER(title) LIKE LOWER(?)', 
                         book_data[:title],  # Full title with series
                         clean_title,         # Title without series
                         "#{clean_title}%")   # Title that starts with
                 .where('LOWER(author) = LOWER(?)', book_data[:author].downcase)
                 .first
      
      if book
        log(:info, "Found book by title/author match: #{book.title} - will add goodreads_id")
        return update_book_attributes(book, book_data)
      end
      
      # Strategy 5: Try fuzzy matching if no ISBNs (be careful here)
      if book_data[:isbn13].blank? && book_data[:isbn].blank?
        similar_books = Book.where('LOWER(author) = LOWER(?)', book_data[:author].downcase)
        
        similar_books.each do |existing_book|
          if titles_match?(existing_book.title, book_data[:title])
            log(:info, "Found book by fuzzy match: #{existing_book.title} - will add goodreads_id")
            return update_book_attributes(existing_book, book_data)
          end
        end
      end
      
      # No match found, create new
      log(:info, "Creating new book: #{book_data[:title]}")
      book = Book.new
      update_book_attributes(book, book_data)
    end
    
    def create_or_update_book_read(book, book_data)
      # Goodreads doesn't provide started_on, so we'll estimate or leave nil
      # But we have read_at for finished date
      
      # Check if we already have a read for this date
      book_read = if book_data[:read_at].present?
        book.book_reads.find_or_initialize_by(finished_on: book_data[:read_at])
      else
        # No read date, but marked as read - create without dates
        book.book_reads.build
      end
      
      book_read.assign_attributes(
        started_on: book_data[:started_at], # Will often be nil from Goodreads
        rating: book_data[:rating],
        metadata: {
          goodreads_review_id: book_data[:review_id],
          date_added: book_data[:date_added],
          imported_at: Time.current
        }
      )
      
      book_read.save!
      
      # Handle multiple reads if read_count > 1
      if book_data[:read_count] && book_data[:read_count] > 1
        log(:info, "Book has been read #{book_data[:read_count]} times on Goodreads")
        # We only have one date, so we can't create accurate historical reads
        # The user will need to manually add those if desired
        book.update_column(:times_read, book_data[:read_count])
      end
    end
    
    def download_cover_image(book, image_url)
      # Use the existing job
      DownloadBookCoverJob.perform_later(book, image_url)
    end

    def update_book_attributes(book, book_data)
      # Always preserve hardcover_id if it exists
      existing_hardcover_id = book.hardcover_id
      
      book.assign_attributes(
        title: book_data[:title],
        author: book_data[:author],
        goodreads_id: book_data[:goodreads_id],  # Always update this
        isbn: book_data[:isbn] || book.isbn,
        isbn13: book_data[:isbn13] || book.isbn13,
        page_count: book_data[:page_count] || book.page_count,
        published_year: book_data[:published_year] || book.published_year,
        publisher: book_data[:publisher] || book.publisher,
        description: book_data[:description] || book.description,
        series: book_data[:series_name] || book.series,
        series_position: book_data[:series_position] || book.series_position,
        hardcover_id: existing_hardcover_id,  # Preserve if exists
        status: 'read',
        metadata: (book.metadata || {}).merge(
          goodreads_import: {
            imported_at: Time.current,
            review_id: book_data[:review_id]
          }
        )
      )
      
      book.save!
      book
    end

    def titles_match?(title1, title2)
      # Clean both titles
      clean1 = clean_title_for_matching(title1)
      clean2 = clean_title_for_matching(title2)
      
      # Exact match after cleaning
      return true if clean1 == clean2
      
      # One contains the other (for subtitles)
      return true if clean1.include?(clean2) || clean2.include?(clean1)
      
      # Very similar (90%+ match)
      similarity = calculate_similarity(clean1, clean2)
      similarity >= 0.90
    end

    def clean_title_for_matching(title)
      title.downcase
           .gsub(/\s*\([^)]*\)\s*$/, '')  # Remove series in parentheses
           .gsub(/[^a-z0-9\s]/, '')       # Remove punctuation
           .gsub(/\b(the|a|an)\b/, '')    # Remove articles
           .strip
           .gsub(/\s+/, ' ')               # Normalize spaces
    end

    def calculate_similarity(str1, str2)
      longer = [str1.length, str2.length].max
      return 1.0 if longer == 0
      
      distance = levenshtein_distance(str1, str2)
      1.0 - (distance.to_f / longer)
    end

    def levenshtein_distance(s1, s2)
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
