import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input",
    "hidden",
    "results",
    "newFields"
  ]
  
  static values = {
    url: String,
    minLength: { type: Number, default: 2 },
    delay: { type: Number, default: 300 },
    createNew: { type: Boolean, default: false }
  }
  
  connect() {
    this.timeout = null
    this.selectedIndex = -1
    
    // Create results container if it doesn't exist
    if (!this.hasResultsTarget) {
      this.createResultsContainer()
    }
    
    // Hide results on click outside
    this.boundClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
  }
  
  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
    if (this.timeout) clearTimeout(this.timeout)
  }
  
  createResultsContainer() {
    const container = document.createElement("div")
    container.dataset.autocompleteTarget = "results"
    container.className = "absolute z-10 mt-1 w-full bg-white shadow-lg max-h-60 rounded-md py-1 text-base ring-1 ring-black ring-opacity-5 overflow-auto focus:outline-none sm:text-sm hidden"
    this.inputTarget.parentElement.appendChild(container)
    this.inputTarget.parentElement.classList.add("relative")
  }
  
  search(event) {
    clearTimeout(this.timeout)
    const query = event.target.value.trim()
    
    if (query.length < this.minLengthValue) {
      this.hideResults()
      return
    }
    
    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, this.delayValue)
  }
  
  async performSearch(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      const data = await response.json()
      this.displayResults(data, query)
    } catch (error) {
      console.error("Search error:", error)
      this.hideResults()
    }
  }
  
  displayResults(data, query) {
    if (!this.hasResultsTarget) return
    
    this.resultsTarget.innerHTML = ""
    this.selectedIndex = -1
    
    if (data.length === 0) {
      if (this.createNewValue) {
        this.addCreateNewOption(query)
      } else {
        this.addNoResultsMessage()
      }
    } else {
      data.forEach((item, index) => {
        this.addResultItem(item, index)
      })
      
      if (this.createNewValue) {
        this.addCreateNewOption(query)
      }
    }
    
    this.showResults()
  }
  
  addResultItem(item, index) {
    const div = document.createElement("div")
    div.className = "cursor-pointer select-none relative py-2 pl-3 pr-9 hover:bg-indigo-50"
    div.dataset.index = index
    div.dataset.id = item.id
    div.dataset.name = item.name
    
    const text = item.display_name || item.name
    div.innerHTML = `
      <span class="block truncate">${this.highlightMatch(text, this.inputTarget.value)}</span>
    `
    
    div.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.selectResult(item)
    })
    this.resultsTarget.appendChild(div)
  }
  
  addCreateNewOption(query) {
    const div = document.createElement("div")
    div.className = "cursor-pointer select-none relative py-2 pl-3 pr-9 bg-indigo-600 text-white hover:bg-indigo-700"
    div.dataset.action = "new"
    
    div.innerHTML = `
      <span class="block truncate">
        <svg class="inline-block w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
        </svg>
        Create new "${this.escapeHtml(query)}"
      </span>
    `
    
    div.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.showNewFields(query)
    })
    this.resultsTarget.appendChild(div)
  }
  
  addNoResultsMessage() {
    const div = document.createElement("div")
    div.className = "py-2 pl-3 pr-9 text-gray-500"
    div.textContent = "No results found"
    this.resultsTarget.appendChild(div)
  }
  
  highlightMatch(text, query) {
    const escaped = this.escapeHtml(query)
    const regex = new RegExp(`(${escaped})`, 'gi')
    return this.escapeHtml(text).replace(regex, '<strong>$1</strong>')
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
  
  selectResult(item) {
    this.inputTarget.value = item.name
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = item.id
    }
    this.hideResults()
    this.hideNewFields()
    
    // Dispatch custom event for other controllers to listen to
    this.dispatch("selected", { detail: item })
  }
  
  showNewFields(queryOrEvent) {
    // Handle both direct string calls and event-triggered calls
    let query
    if (typeof queryOrEvent === 'string') {
      query = queryOrEvent
    } else if (queryOrEvent && queryOrEvent.preventDefault) {
      queryOrEvent.preventDefault()
      query = this.inputTarget.value
    } else {
      query = this.inputTarget.value
    }
    
    this.inputTarget.value = query
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = ""
    }
    
    if (this.hasNewFieldsTarget) {
      this.newFieldsTarget.classList.remove("hidden")
      const firstInput = this.newFieldsTarget.querySelector("input[type='text']")
      if (firstInput) {
        firstInput.value = query
        firstInput.focus()
      }
    }
    
    this.hideResults()
    this.dispatch("new", { detail: { query } })
  }
  
  hideNewFields() {
    if (this.hasNewFieldsTarget) {
      this.newFieldsTarget.classList.add("hidden")
      this.newFieldsTarget.querySelectorAll("input").forEach(input => {
        input.value = ""
      })
    }
  }
  
  navigate(event) {
    if (!this.resultsTarget || this.resultsTarget.classList.contains("hidden")) {
      return
    }
    
    const items = this.resultsTarget.querySelectorAll("[data-index]")
    
    switch(event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.highlightSelected(items)
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
        this.highlightSelected(items)
        break
      case "Enter":
        event.preventDefault()
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          items[this.selectedIndex].click()
        }
        break
      case "Escape":
        event.preventDefault()
        this.hideResults()
        break
    }
  }
  
  highlightSelected(items) {
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add("bg-indigo-50")
      } else {
        item.classList.remove("bg-indigo-50")
      }
    })
  }
  
  showResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove("hidden")
    }
  }
  
  hideResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add("hidden")
    }
    this.selectedIndex = -1
  }
  
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }
  
  clearInput(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    
    this.inputTarget.value = ""
    if (this.hasHiddenTarget) {
      this.hiddenTarget.value = ""
    }
    this.hideResults()
    this.hideNewFields()
    this.inputTarget.focus()
  }
}