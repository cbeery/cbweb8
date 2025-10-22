import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template", "fields"]
  
  connect() {
    this.index = Date.now()
  }
  
  add(event) {
    event?.preventDefault()
    
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, this.index++)
    this.containerTarget.insertAdjacentHTML("beforeend", content)
    
    // Focus the new input
    const newField = this.containerTarget.lastElementChild
    const input = newField.querySelector('input[type="text"]')
    if (input) input.focus()
  }
  
  remove(event) {
    event?.preventDefault()
    
    const field = event.target.closest("[data-artist-fields-target='fields']")
    
    // Check if this is a persisted record
    const destroyInput = field.querySelector("input[name*='_destroy']")
    
    if (destroyInput) {
      // Mark for destruction instead of removing
      destroyInput.value = "1"
      field.style.display = "none"
    } else {
      // New record, safe to remove
      field.remove()
    }
    
    // Ensure at least one field remains
    const visibleFields = this.fieldsTargets.filter(f => f.style.display !== "none")
    if (visibleFields.length === 0) {
      this.add()
    }
  }
}