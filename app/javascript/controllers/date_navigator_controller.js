// app/javascript/controllers/date_navigator_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Date navigator connected to:", this.element)
  }
  
  navigate(event) {
    const date = event.target.value
    console.log("Navigating to date:", date)
    
    if (date) {
      // Simple navigation - just change the URL
      window.location.href = `/admin/nba/games?date=${date}`
    }
  }
}