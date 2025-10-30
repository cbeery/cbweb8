# app/controllers/admin/pages_controller.rb
class Admin::PagesController < Admin::BaseController
  before_action :set_page, only: [:show, :edit, :update, :destroy]
  
  def index
    @pages = Page.all
    @pages = @pages.where("name ILIKE :query OR slug ILIKE :query", query: "%#{params[:q]}%") if params[:q].present?
    @pages = case params[:status]
             when 'published'
               @pages.published
             when 'draft'
               @pages.drafts
             else
               @pages
             end
    @pages = @pages.order(created_at: :desc).page(params[:page])
  end
  
  def show
  end
  
  def new
    @page = Page.new
  end
  
  def create
    @page = Page.new(page_params)
    
    if @page.save
      redirect_to admin_page_path(@page), notice: 'Page was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @page.update(page_params)
      redirect_to admin_page_path(@page), notice: 'Page was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @page.destroy!
    redirect_to admin_pages_path, notice: 'Page was successfully deleted.'
  end
  
  private
  
  def set_page
    @page = Page.find_by!(slug: params[:id])
  end
  
  def page_params
    params.require(:page).permit(
      :slug, 
      :name, 
      :heading, 
      :subheading, 
      :content,
      :published_on,
      :modified_on,
      :public,
      :show_in_index,
      :show_in_recent,
      :hide_from_search_engines,
      :hide_breadcrumbs,
      :hide_footer
    )
  end
end
