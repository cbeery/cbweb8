# app/helpers/viewings_helper.rb
module ViewingsHelper
  # Renders an SVG icon for the viewing location
  # @param location [String] The location value (e.g., 'home', 'theater', 'netflix')
  # @param size [String] Size class: 'sm' (w-4 h-4), 'md' (w-5 h-5), 'lg' (w-6 h-6)
  # @param css_class [String] Additional CSS classes (default: 'text-gray-400')
  def viewing_location_icon(location, size: 'sm', css_class: 'text-gray-400')
    size_class = case size
                 when 'sm' then 'w-4 h-4'
                 when 'md' then 'w-5 h-5'
                 when 'lg' then 'w-6 h-6'
                 else size # Allow passing custom size class
                 end

    icon_data = location_icon_data(location)
    
    content_tag(:svg, 
      content_tag(:path, nil, d: icon_data[:path], fill_rule: icon_data[:fill_rule], clip_rule: icon_data[:clip_rule]).html_safe,
      class: "#{size_class} #{css_class}",
      fill: "currentColor",
      viewBox: icon_data[:viewbox],
      title: icon_data[:title]
    )
  end

  # Returns human-readable label for a location value
  def viewing_location_label(location)
    Viewing.location_options.find { |label, value| value == location }&.first || location&.titleize
  end

  private

  def location_icon_data(location)
    case location.to_s
    when 'home'
      {
        title: 'Home',
        viewbox: '0 0 20 20',
        path: 'M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'theater'
      {
        title: 'Theater',
        viewbox: '0 0 20 20',
        path: 'M2 6a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 100 4v2a2 2 0 01-2 2H4a2 2 0 01-2-2v-2a2 2 0 100-4V6z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'airplane'
      {
        title: 'Airplane',
        viewbox: '0 0 24 24',
        path: 'M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'streaming'
      {
        title: 'Streaming',
        viewbox: '0 0 24 24',
        path: 'M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 14H3V5h18v12zM9 10l7 4-7 4V10z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'netflix'
      {
        title: 'Netflix',
        viewbox: '0 0 55 100',
        path: 'M0 0 L20 0 L20 100 L0 100 Z M35 0 L55 0 L55 100 L35 100 Z M0 0 L20 0 L55 100 L35 100 Z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'appletv'
      {
        title: 'Apple TV+',
        viewbox: '0 0 24 24',
        path: 'M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'hulu'
      {
        title: 'Hulu',
        viewbox: '0 0 24 24',
        path: 'M2 4v16h3.5v-6.5c0-1.1.9-2 2-2s2 .9 2 2V20h3.5v-6.5c0-1.1.9-2 2-2s2 .9 2 2V20H20v-7c0-2.76-2.24-5-5-5-1.38 0-2.63.56-3.53 1.47-.9-.91-2.15-1.47-3.53-1.47-2.76 0-5 2.24-5 5v7H2V4z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'hbo'
      {
        title: 'HBO / Max',
        viewbox: '0 0 24 24',
        path: 'M2 6v12h3V13h3v5h3V6H8v4H5V6H2zm11 0v12h4.5c2.5 0 4.5-2.7 4.5-6s-2-6-4.5-6H13zm3 3h1.5c.83 0 1.5 1.34 1.5 3s-.67 3-1.5 3H16V9z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'disney'
      {
        title: 'Disney+',
        viewbox: '0 0 24 24',
        path: 'M3 2c-.55 0-1 .45-1 1v18c0 .55.45 1 1 1h18c.55 0 1-.45 1-1V3c0-.55-.45-1-1-1H3zm9 4.5c3.86 0 7 2.69 7 6s-3.14 6-7 6-7-2.69-7-6 3.14-6 7-6zm0 2c-2.76 0-5 1.79-5 4s2.24 4 5 4 5-1.79 5-4-2.24-4-5-4z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'amazon'
      {
        title: 'Amazon Prime',
        viewbox: '0 0 24 24',
        path: 'M21.96 13.34c-.1-.12-.27-.14-.39-.04-.03.02-.06.05-.08.08-.7 1.09-1.47 2.05-2.45 2.91-2.27 1.99-5.08 3.09-8.05 3.27-.49.03-.98.04-1.47.02-3.4-.14-6.21-1.46-8.4-3.97-.15-.17-.4-.19-.57-.04-.17.15-.19.4-.04.57 2.36 2.72 5.44 4.16 9.13 4.31.55.02 1.1.01 1.65-.03 3.23-.19 6.27-1.39 8.71-3.53 1.06-.93 1.9-1.98 2.65-3.16.09-.14.05-.33-.09-.43-.06-.04-.13-.06-.2-.05l-.4.09zM14.57 7.77c-.36-.2-.75-.36-1.17-.46-.41-.1-.85-.15-1.31-.15-.73 0-1.41.14-2.04.41-.63.28-1.18.67-1.64 1.18-.46.51-.82 1.11-1.07 1.81-.25.7-.37 1.47-.37 2.32 0 .84.12 1.6.37 2.28.25.68.6 1.26 1.05 1.73.45.47.99.84 1.61 1.09.62.26 1.31.38 2.05.38.48 0 .94-.06 1.37-.17.43-.11.83-.28 1.2-.5.37-.22.7-.49.99-.81.29-.32.52-.68.7-1.08l-1.77-.68c-.12.28-.27.52-.45.72-.18.2-.38.36-.61.49-.22.13-.47.22-.73.27-.26.05-.53.08-.81.08-.49 0-.93-.09-1.31-.27-.38-.18-.71-.44-.97-.77-.27-.33-.47-.73-.61-1.19-.14-.46-.21-.98-.21-1.55 0-.59.08-1.12.23-1.59.15-.47.37-.87.65-1.2.28-.33.62-.59 1.01-.77.39-.18.83-.27 1.31-.27.54 0 1.01.11 1.42.32.41.22.73.53.97.93l1.65-.87c-.16-.3-.36-.57-.6-.81-.24-.25-.52-.45-.84-.62z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'peacock'
      {
        title: 'Peacock',
        viewbox: '0 0 24 24',
        path: 'M12 2C8.69 2 6 4.69 6 8c0 2.34 1.34 4.36 3.29 5.35-.29.57-.48 1.19-.58 1.84C4.98 14.9 2 11.76 2 8c0-5.52 4.48-10 10-10s10 4.48 10 10c0 3.76-2.98 6.9-6.71 7.19-.1-.65-.29-1.27-.58-1.84C16.66 12.36 18 10.34 18 8c0-3.31-2.69-6-6-6zm0 14c-1.66 0-3 1.34-3 3v3h6v-3c0-1.66-1.34-3-3-3z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'hoopla'
      {
        title: 'Hoopla',
        viewbox: '0 0 24 24',
        path: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13v6l5 3-1 1.73-6-3.6V7h2z',
        fill_rule: nil,
        clip_rule: nil
      }
    when 'kanopy'
      {
        title: 'Kanopy',
        viewbox: '0 0 24 24',
        path: 'M4 4v16h16V4H4zm14 14H6V6h12v12zm-6-9L8 12l4 3V9zm1 0v6l4-3-4-3z',
        fill_rule: nil,
        clip_rule: nil
      }
    else # 'other' or unknown
      {
        title: location&.titleize || 'Other',
        viewbox: '0 0 20 20',
        path: 'M2 5a2 2 0 012-2h12a2 2 0 012 2v10a2 2 0 01-2 2H4a2 2 0 01-2-2V5zm3.293 1.293a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 01-1.414-1.414L7.586 10 5.293 7.707a1 1 0 010-1.414zM11 12a1 1 0 100 2h3a1 1 0 100-2h-3z',
        fill_rule: 'evenodd',
        clip_rule: 'evenodd'
      }
    end
  end
end
