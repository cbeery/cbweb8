import { Controller } from "@hotwired/stimulus"

// Collapsible controller for show/hide toggle behavior
// Used for mobile navigation menus that should be collapsed by default
export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { open: { type: Boolean, default: false } }

  connect() {
    this.updateVisibility()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.updateVisibility()
  }

  updateVisibility() {
    if (this.hasContentTarget) {
      if (this.openValue) {
        this.contentTarget.classList.remove("hidden")
      } else {
        this.contentTarget.classList.add("hidden")
      }
    }

    if (this.hasIconTarget) {
      if (this.openValue) {
        this.iconTarget.classList.add("rotate-180")
      } else {
        this.iconTarget.classList.remove("rotate-180")
      }
    }
  }
}
