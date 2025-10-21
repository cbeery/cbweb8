import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 
    "venueSelect", 
    "newVenueFields", 
    "newVenueName",
    "artistsContainer", 
    "artistField",
    "artistSelect",
    "newArtistInput",
    "destroyInput"
  ]
  
  connect() {
    // Initialize any existing artist selects
    this.artistSelectTargets.forEach(select => {
      if (select.value === "new") {
        this.showNewArtistInput(select)
      }
    })
  }
  
  toggleVenueFields(event) {
    const select = event.target
    
    if (select.value === "") {
      // "Add New Venue" option selected
      this.newVenueFieldsTarget.classList.remove("hidden")
      // Focus the venue name field
      if (this.hasNewVenueNameTarget) {
        this.newVenueNameTarget.focus()
      }
    } else {
      // Regular venue or prompt selected
      this.newVenueFieldsTarget.classList.add("hidden")
      // Clear the new venue fields
      this.newVenueFieldsTarget.querySelectorAll("input").forEach(input => {
        input.value = ""
      })
    }
  }
  
  addArtist(event) {
    event.preventDefault()
    
    const timestamp = new Date().getTime()
    const template = this.artistFieldTargets[0].cloneNode(true)
    
    // Clear values and update names with new timestamp
    template.querySelectorAll("input, select").forEach(field => {
      if (field.name) {
        field.name = field.name.replace(/\[\d+\]/, `[${timestamp}]`)
      }
      if (field.type === "hidden" && field.name.includes("[id]")) {
        field.value = ""
      } else if (field.type === "text") {
        field.value = ""
        field.classList.add("hidden")
      } else if (field.tagName === "SELECT") {
        field.value = ""
      }
    })
    
    // Reset the destroy field
    const destroyField = template.querySelector('[data-concert-form-target="destroyInput"]')
    if (destroyField) {
      destroyField.value = "false"
    }
    
    this.artistsContainerTarget.appendChild(template)
    
    // Focus the new select
    const newSelect = template.querySelector("select")
    if (newSelect) {
      newSelect.focus()
    }
  }
  
  removeArtist(event) {
    event.preventDefault()
    
    const artistField = event.target.closest('[data-concert-form-target="artistField"]')
    
    // If this is a persisted record, mark it for destruction
    const idField = artistField.querySelector('input[name*="[id]"]')
    if (idField && idField.value) {
      const destroyField = artistField.querySelector('[data-concert-form-target="destroyInput"]')
      if (destroyField) {
        destroyField.value = "true"
        artistField.style.display = "none"
      }
    } else {
      // New record, just remove it
      artistField.remove()
    }
    
    // Ensure at least one artist field remains
    const visibleFields = this.artistFieldTargets.filter(field => 
      field.style.display !== "none"
    )
    if (visibleFields.length === 0) {
      this.addArtist(event)
    }
  }
  
  handleArtistSelection(event) {
    const select = event.target
    
    if (select.value === "new") {
      this.showNewArtistInput(select)
    } else {
      this.hideNewArtistInput(select)
    }
  }
  
  showNewArtistInput(select) {
    const container = select.closest('[data-concert-form-target="artistField"]')
    const textInput = container.querySelector('[data-concert-form-target="newArtistInput"]')
    
    if (textInput) {
      select.classList.add("hidden")
      textInput.classList.remove("hidden")
      textInput.focus()
      
      // Add a back button or escape handler
      textInput.addEventListener("keydown", (e) => {
        if (e.key === "Escape") {
          select.value = ""
          this.hideNewArtistInput(select)
        }
      })
    }
  }
  
  hideNewArtistInput(select) {
    const container = select.closest('[data-concert-form-target="artistField"]')
    const textInput = container.querySelector('[data-concert-form-target="newArtistInput"]')
    
    if (textInput) {
      select.classList.remove("hidden")
      textInput.classList.add("hidden")
      textInput.value = ""
    }
  }
}