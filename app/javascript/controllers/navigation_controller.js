// app/javascript/controllers/navigation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    console.log("Navigation controller connected!")
    // Bind this context for event listeners
    this.handleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener('keydown', this.handleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleGlobalKeydown)
  }

  open() {
    console.log("Opening navigation")
    this.overlayTarget.style.display = 'block'
    // Force a reflow before adding the class for smooth animation
    this.overlayTarget.offsetHeight
    this.overlayTarget.classList.remove('-translate-y-full')
    this.overlayTarget.classList.add('translate-y-0')
    document.body.style.overflow = 'hidden'
  }

  close() {
    console.log("Closing navigation")
    this.overlayTarget.classList.remove('translate-y-0')
    this.overlayTarget.classList.add('-translate-y-full')
    document.body.style.overflow = ''
    
    // Hide the overlay after animation completes
    setTimeout(() => {
      this.overlayTarget.style.display = 'none'
    }, 300)
  }

  clickOutside(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  handleKeydown(event) {
    // Close on Escape key
    if (event.key === 'Escape' && this.overlayTarget.style.display !== 'none') {
      this.close()
    }
  }

  handleGlobalKeydown(event) {
    // Open on Cmd/Ctrl + K
    if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
      event.preventDefault()
      if (this.overlayTarget.style.display === 'none') {
        this.open()
      } else {
        this.close()
      }
    }
  }
}