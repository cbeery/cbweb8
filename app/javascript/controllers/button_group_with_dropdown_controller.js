// app/javascript/controllers/button_group_with_dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "dropdown", "dropdownLabel" ]
  
  connect() {
    // Initialize selected value
    if (this.hasInputTarget && this.inputTarget.value) {
      this.highlightSelection(this.inputTarget.value)
    }
    
    // Close dropdown when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener('click', this.boundClickOutside)
  }
  
  disconnect() {
    document.removeEventListener('click', this.boundClickOutside)
  }
  
  selectButton(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const value = event.currentTarget.dataset.buttonGroupValue
    this.setValue(value)
    this.highlightSelection(value)
  }
  
  selectDropdown(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const value = event.currentTarget.dataset.buttonGroupValue
    this.setValue(value)
    
    // Update dropdown button label
    if (this.hasDropdownLabelTarget) {
      this.dropdownLabelTargets.forEach(label => {
        if (label.closest('.relative').querySelector('[data-button-group-with-dropdown-target="dropdown"]').contains(event.currentTarget)) {
          label.textContent = value
        }
      })
    }
    
    this.hideDropdowns()
    this.highlightSelection(value)
  }
  
  toggleDropdown(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const dropdown = event.currentTarget.closest('.relative').querySelector('[data-button-group-with-dropdown-target="dropdown"]')
    if (dropdown) {
      const isHidden = dropdown.classList.contains('hidden')
      this.hideDropdowns()
      if (isHidden) {
        dropdown.classList.remove('hidden')
      }
    }
  }
  
  hideDropdowns() {
    this.dropdownTargets.forEach(dropdown => {
      dropdown.classList.add('hidden')
    })
  }
  
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdowns()
    }
  }
  
  setValue(value) {
    if (this.hasInputTarget) {
      this.inputTarget.value = value
    }
  }
  
  highlightSelection(value) {
    // Clear all button highlights
    const buttons = this.element.querySelectorAll('button[data-button-group-value]')
    buttons.forEach(btn => {
      // Skip dropdown toggle buttons
      if (btn.dataset.action?.includes('toggleDropdown')) return
      
      if (btn.dataset.buttonGroupValue === value) {
        // Highlight selected
        btn.classList.remove('bg-white', 'text-gray-700', 'border-gray-300', 'hover:bg-gray-50')
        btn.classList.add('bg-indigo-600', 'text-white', 'border-indigo-600')
      } else {
        // Reset others
        btn.classList.remove('bg-indigo-600', 'text-white', 'border-indigo-600', 'bg-indigo-50', 'text-indigo-600')
        btn.classList.add('bg-white', 'text-gray-700', 'border-gray-300', 'hover:bg-gray-50')
      }
    })
    
    // Update dropdown items
    const dropdownItems = this.element.querySelectorAll('[data-button-group-with-dropdown-target="dropdown"] button')
    dropdownItems.forEach(item => {
      if (item.dataset.buttonGroupValue === value) {
        item.classList.add('bg-indigo-50', 'text-indigo-600')
        item.classList.remove('text-gray-700')
        
        // Update the dropdown button label if this value is selected
        const dropdown = item.closest('[data-button-group-with-dropdown-target="dropdown"]')
        const label = dropdown.closest('.relative').querySelector('[data-button-group-with-dropdown-target="dropdownLabel"]')
        if (label) {
          label.textContent = value
        }
      } else {
        item.classList.remove('bg-indigo-50', 'text-indigo-600')
        item.classList.add('text-gray-700')
      }
    })
  }
}