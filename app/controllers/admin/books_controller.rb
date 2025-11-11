# app/controllers/admin/books_controller.rb
class Admin::BooksController < Admin::BaseController
  before_action :set_book, only: [:show, :edit, :update]
  
  def index
    @books = Book.includes(:cover_image_attachment, :most_recent_read)
    
    # Status filter
    if params[:status].present?
      @books = @books.where(status: params[:status])
    else
      # Default to read books
      @books = @books.read
    end
    
    # Search
    if params[:search].present?
      @books = @books.where("title ILIKE :q OR author ILIKE :q", q: "%#{params[:search]}%")
    end
    
    # Sorting
    @books = case params[:sort]
    when 'title'
      @books.order(:title)
    when 'author'
      @books.order(:author, :title)
    when 'rating'
      @books.order(rating: :desc, updated_at: :desc)
    when 'started'
      # Join with book_reads to sort by most recent start date
      @books.left_joins(:book_reads)
            .group('books.id')
            .order('MAX(book_reads.started_on) DESC NULLS LAST')
    when 'finished'
      # Join with book_reads to sort by most recent finish date
      @books.left_joins(:book_reads)
            .group('books.id')
            .order('MAX(book_reads.finished_on) DESC NULLS LAST')
    else
      # Default: For read books, sort by most recent read date
      # For other statuses, sort by updated_at
      if params[:status] == 'read' || (params[:status].blank? && @books == Book.read)
        @books.left_joins(:book_reads)
              .group('books.id')
              .order('MAX(book_reads.finished_on) DESC NULLS LAST, books.updated_at DESC')
      else
        @books.order(updated_at: :desc)
      end
    end
    
    @total_count = @books.count
    @books = @books.page(params[:page]).per(50)
  end
  
  def show
    @metadata = @book.metadata || {}
    @book_reads = @book.book_reads.recent if defined?(BookRead)
  end
  
  def edit
    # For compatibility, we'll edit the most recent read if it exists
    @current_read = @book.book_reads.recent.first if defined?(BookRead)
  end
  
  def update
    if @book.update(book_params)
      # Mark as manually uploaded if a new cover was uploaded
      if params[:book][:cover_image].present?
        @book.update(cover_manually_uploaded: true)
      end
      
      # Handle date updates if BookRead exists
      if defined?(BookRead)
        handle_book_read_updates
      end
      
      redirect_to admin_book_path(@book), notice: 'Book was successfully updated.'
    else
      render :edit
    end
  end
  
  private
  
  def set_book
    @book = Book.find(params[:id])
  end
  
  def book_params
    # Remove date fields if they don't exist on Book model
    permitted = [:title, :author, :status, :rating, :progress, :times_read, 
                 :series, :series_position, :page_count, :published_year, 
                 :publisher, :description, :cover_image]
    
    # Only include date fields if columns still exist (pre-migration compatibility)
    if Book.column_names.include?('started_on')
      permitted += [:started_on, :finished_on]
    end
    
    params.require(:book).permit(*permitted)
  end
  
  def handle_book_read_updates
    # If dates were provided in the form, update the most recent read
    started_on = params[:book][:started_on]
    finished_on = params[:book][:finished_on]
    
    if started_on.present? || finished_on.present?
      # Find or create a book read
      book_read = if @book.status == 'currently_reading'
        @book.current_read || @book.book_reads.build
      else
        @book.most_recent_read || @book.book_reads.build
      end
      
      book_read.started_on = started_on if started_on.present?
      book_read.finished_on = finished_on if finished_on.present?
      book_read.rating = params[:book][:rating] if params[:book][:rating].present?
      book_read.save
    end
  end
end
