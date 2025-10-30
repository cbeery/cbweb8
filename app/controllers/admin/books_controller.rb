# app/controllers/admin/books_controller.rb
class Admin::BooksController < Admin::BaseController
  before_action :set_book, only: [:show, :edit, :update]
  
  def index
    @books = Book.includes(:cover_image_attachment)
    
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
      @books.order(rating: :desc, finished_on: :desc)
    when 'started'
      @books.order(started_on: :desc)
    else
      # Default: finished_on desc for read books
      @books.order(finished_on: :desc)
    end
    
    @total_count = @books.count
    @books = @books.page(params[:page]).per(50)
  end
  
  def show
    @metadata = @book.metadata || {}
  end
  
  def edit
  end
  
  def update
    if @book.update(book_params)
      # Mark as manually uploaded if a new cover was uploaded
      if params[:book][:cover_image].present?
        @book.update(cover_manually_uploaded: true)
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
    params.require(:book).permit(
      :title, :author, :status, :started_on, :finished_on,
      :rating, :progress, :times_read, :series, :series_position,
      :page_count, :published_year, :publisher, :description,
      :cover_image
    )
  end
end