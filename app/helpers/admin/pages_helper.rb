# app/helpers/admin/pages_helper.rb
module Admin::PagesHelper
  def page_status_badge(page)
    if page.published?
      content_tag :span, "Published", 
                  class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
    else
      content_tag :span, "Draft", 
                  class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
    end
  end
  
  def page_visibility_badge(page)
    if page.public
      content_tag :span, "Public", 
                  class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
    else
      content_tag :span, "Private", 
                  class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
    end
  end
  
  def page_display_options_summary(page)
    options = []
    options << "Index" if page.show_in_index
    options << "Recent" if page.show_in_recent
    options << "NoIndex" if page.hide_from_search_engines
    options << "No Breadcrumbs" if page.hide_breadcrumbs
    options << "No Footer" if page.hide_footer
    
    options.empty? ? "Default" : options.join(", ")
  end
end
