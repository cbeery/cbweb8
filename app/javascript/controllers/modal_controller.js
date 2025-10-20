// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  
  open(event) {
    event.preventDefault()
    
    fetch(this.urlValue, {
      headers: {
        "Accept": "text/html"
      }
    })
    .then(response => response.text())
    .then(html => {
      document.getElementById("modal_container").innerHTML = html
    })
  }
}