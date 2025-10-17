// app/javascript/controllers/modal_backdrop_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    if (event.target === event.currentTarget) {
      this.element.remove()
    }
  }
}
