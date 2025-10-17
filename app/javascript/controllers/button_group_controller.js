// app/javascript/controllers/button_group_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]
  
  select(event) {
    event.preventDefault()
    
    // Update visual state
    const buttons = event.currentTarget.parentElement.querySelectorAll("button")
    buttons.forEach(btn => {
      btn.classList.remove("bg-indigo-600", "text-white", "border-indigo-600")
      btn.classList.add("bg-white", "text-gray-700", "border-gray-300", "hover:bg-gray-50")
    })
    
    event.currentTarget.classList.remove("bg-white", "text-gray-700", "border-gray-300", "hover:bg-gray-50")
    event.currentTarget.classList.add("bg-indigo-600", "text-white", "border-indigo-600")
    
    // Update hidden input
    const value = event.currentTarget.dataset.buttonGroupValue
    if (this.hasInputTarget) {
      this.inputTarget.value = value
    }
  }
}