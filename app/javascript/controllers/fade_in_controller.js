// fade_in_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1) {
            node.classList.add('fade-in-new')
            
            // Remove class after animation completes
            node.addEventListener('animationend', () => {
              node.classList.remove('fade-in-new')
            }, { once: true })
          }
        })
      })
    })
    
    observer.observe(this.element, { childList: true })
    this.observer = observer
  }
  
  disconnect() {
    this.observer?.disconnect()
  }
}