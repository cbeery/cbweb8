# Tailwind CSS Grid & Flex Guide for Rails Developers

## Understanding Tailwind's Layout Systems

Tailwind provides two main layout systems: **CSS Grid** and **Flexbox**. Each has its strengths and ideal use cases.

## 1. CSS Grid - The 2D Layout System

Grid is perfect when you need to control both rows AND columns simultaneously. Think of it as a spreadsheet where you can place items in specific cells and have them span multiple cells.

### Basic Grid Setup

```erb
<!-- Basic 3-column grid -->
<div class="grid grid-cols-3 gap-4">
  <div>Item 1</div>
  <div>Item 2</div>
  <div>Item 3</div>
</div>
```

### Key Grid Classes

| Class | Purpose | Example |
|-------|---------|---------|
| `grid` | Enable CSS Grid | Required to start |
| `grid-cols-{n}` | Set column count (1-12) | `grid-cols-4` = 4 equal columns |
| `col-span-{n}` | Span multiple columns | `col-span-2` = spans 2 columns |
| `grid-rows-{n}` | Set row count | `grid-rows-3` = 3 rows |
| `row-span-{n}` | Span multiple rows | `row-span-2` = spans 2 rows |
| `gap-{size}` | Gap between all items | `gap-4` = 1rem gap |
| `gap-x-{size}` | Horizontal gap only | `gap-x-2` = 0.5rem horizontal |
| `gap-y-{size}` | Vertical gap only | `gap-y-4` = 1rem vertical |

### Column Spanning Examples

```erb
<!-- Dashboard layout with main content and sidebar -->
<div class="grid grid-cols-6 gap-4">
  <div class="col-span-4">Main Content (4/6 width)</div>
  <div class="col-span-2">Sidebar (2/6 width)</div>
</div>

<!-- Full-width header with 3-column content below -->
<div class="grid grid-cols-3 gap-4">
  <div class="col-span-3">Full Width Header</div>
  <div>Column 1</div>
  <div>Column 2</div>
  <div>Column 3</div>
</div>
```

### Advanced Grid Features

#### Auto-Flow
Controls how items are automatically placed:
- `grid-flow-row` (default) - Fill by row
- `grid-flow-col` - Fill by column
- `grid-flow-dense` - Fill gaps efficiently

#### Auto-Rows
Set the size of implicitly created rows:
- `auto-rows-min` - Minimum content size
- `auto-rows-max` - Maximum content size
- `auto-rows-fr` - Equal fractions
- `auto-rows-[minmax(200px,1fr)]` - Custom sizing

## 2. Flexbox - The 1D Layout System

Flexbox is ideal for laying out items in a single direction (row OR column). It's perfect for navigation bars, centering content, or distributing space.

### Basic Flex Setup

```erb
<!-- Horizontal flex container -->
<div class="flex gap-4">
  <div>Item 1</div>
  <div>Item 2</div>
  <div>Item 3</div>
</div>

<!-- Vertical flex container -->
<div class="flex flex-col gap-4">
  <div>Item 1</div>
  <div>Item 2</div>
  <div>Item 3</div>
</div>
```

### Key Flex Classes

| Class | Purpose | Values |
|-------|---------|--------|
| `flex` | Enable flexbox | Required to start |
| `flex-row` | Horizontal direction | Default |
| `flex-col` | Vertical direction | Stack items |
| `justify-{value}` | Main axis alignment | start, center, end, between, around, evenly |
| `items-{value}` | Cross axis alignment | start, center, end, stretch, baseline |
| `flex-wrap` | Allow wrapping | Items wrap to new line |
| `flex-1` | Grow to fill space | Takes available space |
| `flex-none` | Don't grow or shrink | Fixed size |

### Common Flex Patterns

```erb
<!-- Center content both ways -->
<div class="flex items-center justify-center h-screen">
  <div>Perfectly Centered</div>
</div>

<!-- Space between navigation -->
<nav class="flex justify-between items-center p-4">
  <div>Logo</div>
  <div class="flex gap-4">
    <a href="#">Home</a>
    <a href="#">About</a>
    <a href="#">Contact</a>
  </div>
</nav>

<!-- Sidebar layout with flex -->
<div class="flex h-screen">
  <aside class="w-64 bg-gray-100">Sidebar</aside>
  <main class="flex-1 p-4">Main Content (grows)</main>
</div>
```

## 3. Responsive Design Patterns

Tailwind uses a mobile-first approach. Start with the smallest screen and add breakpoints for larger screens.

### Breakpoint Prefixes

| Prefix | Min Width | Description |
|--------|-----------|-------------|
| (none) | 0px | Mobile (default) |
| `sm:` | 640px | Small tablets |
| `md:` | 768px | Tablets |
| `lg:` | 1024px | Laptops |
| `xl:` | 1280px | Desktops |
| `2xl:` | 1536px | Large screens |

### Responsive Grid Examples

```erb
<!-- 1 column on mobile, 2 on tablet, 4 on desktop -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
  <% @items.each do |item| %>
    <div><%= item.name %></div>
  <% end %>
</div>

<!-- Responsive column spans -->
<div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
  <!-- Full width on mobile, 2/3 on desktop -->
  <div class="col-span-1 lg:col-span-2">Main Content</div>
  <!-- Full width on mobile, 1/3 on desktop -->
  <div class="col-span-1">Sidebar</div>
</div>
```

## 4. Rails-Specific Patterns

### Dynamic Grid with Rails Data

```erb
<!-- Movie gallery with responsive grid -->
<div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
  <% @movies.each do |movie| %>
    <div class="aspect-square bg-white rounded-lg shadow-sm overflow-hidden">
      <% if movie.poster.attached? %>
        <%= image_tag movie.poster, class: "w-full h-full object-cover" %>
      <% else %>
        <div class="w-full h-full flex items-center justify-center bg-gray-100">
          <span class="text-gray-400">No Image</span>
        </div>
      <% end %>
      <div class="p-2">
        <h3 class="text-sm font-semibold truncate"><%= movie.title %></h3>
      </div>
    </div>
  <% end %>
</div>
```

### Dashboard Layout

```erb
<!-- Admin dashboard with stats and content -->
<div class="space-y-6">
  <!-- Stats row -->
  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
    <% @stats.each do |stat| %>
      <div class="bg-white rounded-lg shadow p-6">
        <p class="text-sm text-gray-600"><%= stat[:label] %></p>
        <p class="text-2xl font-bold"><%= stat[:value] %></p>
        <p class="text-xs text-<%= stat[:trend_positive] ? 'green' : 'red' %>-600">
          <%= stat[:trend] %>
        </p>
      </div>
    <% end %>
  </div>
  
  <!-- Main content area -->
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- Main content - spans 2 columns on large screens -->
    <div class="lg:col-span-2 space-y-6">
      <%= render 'charts' %>
      <%= render 'recent_activity' %>
    </div>
    <!-- Sidebar -->
    <div class="space-y-6">
      <%= render 'quick_actions' %>
      <%= render 'notifications' %>
    </div>
  </div>
</div>
```

## 5. Common Layout Patterns

### Bento Box / Pinterest Style

```erb
<!-- Asymmetric grid with varying sizes -->
<div class="grid grid-cols-4 grid-rows-3 gap-4">
  <div class="col-span-2 row-span-2">Large Feature</div>
  <div class="col-span-1 row-span-1">Small Card</div>
  <div class="col-span-1 row-span-2">Tall Card</div>
  <div class="col-span-1 row-span-1">Small Card</div>
  <div class="col-span-3 row-span-1">Wide Banner</div>
  <div class="col-span-1 row-span-1">Small Card</div>
</div>
```

### Masonry Layout (CSS Columns)

```erb
<!-- True masonry with CSS columns -->
<div class="columns-1 sm:columns-2 lg:columns-3 xl:columns-4 gap-4">
  <% @items.each do |item| %>
    <!-- break-inside-avoid prevents items from breaking across columns -->
    <div class="break-inside-avoid mb-4">
      <div class="bg-white rounded-lg shadow p-4">
        <%= render item %>
      </div>
    </div>
  <% end %>
</div>
```

### Holy Grail Layout

```erb
<!-- Classic header/content/sidebar/footer -->
<div class="min-h-screen flex flex-col">
  <header class="bg-gray-800 text-white p-4">Header</header>
  
  <div class="flex-1 flex">
    <aside class="w-64 bg-gray-100 p-4">Left Sidebar</aside>
    <main class="flex-1 p-6">Main Content</main>
    <aside class="w-64 bg-gray-100 p-4">Right Sidebar</aside>
  </div>
  
  <footer class="bg-gray-800 text-white p-4">Footer</footer>
</div>
```

## 6. Tips and Best Practices

### When to Use Grid vs Flex

**Use Grid when:**
- You need 2D control (rows AND columns)
- Building complex layouts
- Items need to align to both axes
- Creating dashboard layouts
- Building card galleries

**Use Flex when:**
- You need 1D control (row OR column)
- Centering content
- Creating navigation bars
- Distributing space between items
- Building simple component layouts

### Performance Tips

1. **Avoid deeply nested grids** - Keep nesting to 2-3 levels max
2. **Use `gap` instead of margins** - Cleaner and more maintainable
3. **Leverage responsive utilities** - Don't duplicate markup for different screens
4. **Consider CSS columns for masonry** - Better performance than JS solutions

### Rails Partial Patterns

```erb
<!-- _card_grid.html.erb partial -->
<div class="grid <%= local_assigns[:grid_class] || 'grid-cols-1 md:grid-cols-3' %> gap-4">
  <% items.each do |item| %>
    <div class="<%= local_assigns[:card_class] %>">
      <%= yield(item) %>
    </div>
  <% end %>
</div>

<!-- Usage -->
<%= render 'card_grid', 
           items: @movies, 
           grid_class: 'grid-cols-2 lg:grid-cols-4' do |movie| %>
  <%= render 'movie_card', movie: movie %>
<% end %>
```

## 7. Debugging Layout Issues

Common issues and solutions:

1. **Items not spanning correctly**
   - Check parent has `grid` class
   - Verify column count matches span values
   
2. **Gaps not working**
   - Ensure `gap-*` is on the grid/flex container, not children
   
3. **Responsive not working**
   - Remember mobile-first: base styles apply to all screens
   - Larger breakpoints override smaller ones
   
4. **Flex items not growing**
   - Add `flex-1` or `flex-grow` to items that should expand
   - Check for conflicting width classes

## Setting Up Your Test Page

To add the test page to your Rails app:

1. Add route to `config/routes.rb`:
```ruby
get 'home/test11', to: 'home#test11'
```

2. Add controller action to `app/controllers/home_controller.rb`:
```ruby
def test11
  # Add any data loading if needed
end
```

3. Copy the view file to `app/views/home/test11.html.erb`

4. Visit `/home/test11` to see the interactive guide!

## Resources

- [Tailwind CSS Grid Documentation](https://tailwindcss.com/docs/grid-template-columns)
- [Tailwind CSS Flexbox Documentation](https://tailwindcss.com/docs/flex)
- [CSS Grid Garden](https://cssgridgarden.com/) - Interactive game to learn Grid
- [Flexbox Froggy](https://flexboxfroggy.com/) - Interactive game to learn Flexbox
