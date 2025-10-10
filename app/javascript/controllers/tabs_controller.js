// app/javascript/controllers/tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeClass: String }
  
  connect() {
    // Set initial active tab based on URL params if present
    const params = new URLSearchParams(window.location.search)
    const category = params.get('category')
    const period = params.get('period')
    
    if (category) {
      this.selectByPanelId(`${category}-panel`)
    }
    
    if (category && period) {
      // Small delay to ensure nested tabs are initialized
      setTimeout(() => {
        this.selectByPanelId(`${category}-${period}-panel`)
      }, 100)
    }
  }
  
  select(event) {
    const button = event.currentTarget
    const panelId = button.dataset.panelId
    const href = button.dataset.href
    const frameId = button.dataset.turboFrame
    
    this.activateTab(button, panelId)
    
    // Load content via Turbo Frame if needed
    if (href && frameId) {
      const frame = document.getElementById(frameId)
      if (frame && !frame.src) {
        frame.src = href
      }
    }
  }
  
  selectByPanelId(panelId) {
    const tab = this.tabTargets.find(tab => tab.dataset.panelId === panelId)
    if (tab) {
      this.activateTab(tab, panelId)
    }
  }
  
  activateTab(activeButton, panelId) {
    const activeClasses = this.activeClassValue ? this.activeClassValue.split(' ') : []
    
    // Update tab states
    this.tabTargets.forEach(tab => {
      const isActive = tab === activeButton
      
      if (isActive) {
        // Add active classes
        if (activeClasses.length > 0) {
          tab.classList.add(...activeClasses)
        }
        
        // Remove inactive classes based on tab type
        if (tab.classList.contains('border-b-2')) {
          // Main category tabs
          tab.classList.remove('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'hover:border-gray-300')
        } else {
          // Period sub-tabs
          tab.classList.remove('text-gray-500', 'hover:text-gray-700', 'bg-gray-100')
        }
        
        tab.setAttribute('aria-selected', 'true')
      } else {
        // Remove active classes
        if (activeClasses.length > 0) {
          tab.classList.remove(...activeClasses)
        }
        
        // Add inactive classes based on tab type
        if (tab.classList.contains('border-b-2')) {
          // Main category tabs
          tab.classList.add('border-transparent', 'text-gray-500', 'hover:text-gray-700', 'hover:border-gray-300')
        } else {
          // Period sub-tabs
          tab.classList.add('text-gray-500', 'hover:text-gray-700', 'bg-gray-100')
        }
        
        tab.setAttribute('aria-selected', 'false')
      }
    })
    
    // Update panel visibility
    this.panelTargets.forEach(panel => {
      if (panel.id === panelId) {
        panel.classList.remove('hidden')
      } else {
        panel.classList.add('hidden')
      }
    })
  }
}