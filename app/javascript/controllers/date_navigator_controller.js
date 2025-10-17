// app/javascript/controllers/date_navigator_controller.js
import { Controller } from "@hotwired/stimulus"
import { visit } from "@hotwired/turbo"

export default class extends Controller {
  navigate(event) {
    const date = event.target.value
    if (date) {
      visit(`/admin/nba/games?date=${date}`)
    }
  }
}