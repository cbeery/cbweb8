// app/javascript/controllers/viewing_form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "location",
    "theaterSection",
    "theaterId",
    "filmSeriesSelector",
    "filmSeriesEventsSection",
    "filmSeriesEventId",
    "price",
    "format"
  ]

  connect() {
    // Initialize theater section visibility based on current location
    this.toggleTheaterSection()
  }

  toggleTheaterSection() {
    const location = this.locationTarget.value
    const isTheater = location === 'theater'

    if (this.hasTheaterSectionTarget) {
      this.theaterSectionTarget.classList.toggle('hidden', !isTheater)
    }

    // Clear theater-specific fields when not theater
    if (!isTheater) {
      this.clearTheaterFields()
    }
  }

  clearTheaterFields() {
    if (this.hasTheaterIdTarget) {
      this.theaterIdTarget.value = ''
    }
    if (this.hasFilmSeriesSelectorTarget) {
      this.filmSeriesSelectorTarget.value = ''
    }
    if (this.hasFilmSeriesEventsSectionTarget) {
      this.filmSeriesEventsSectionTarget.classList.add('hidden')
    }
    if (this.hasFilmSeriesEventIdTarget) {
      this.filmSeriesEventIdTarget.innerHTML = '<option value="">Select an event...</option>'
      this.filmSeriesEventIdTarget.value = ''
    }
    if (this.hasPriceTarget) {
      this.priceTarget.value = ''
    }
    if (this.hasFormatTarget) {
      this.formatTarget.value = ''
    }
  }

  loadFilmSeriesEvents() {
    const seriesId = this.filmSeriesSelectorTarget.value
    const eventsSection = this.filmSeriesEventsSectionTarget
    const eventsSelect = this.filmSeriesEventIdTarget

    // Capture current value before changes
    const currentValue = eventsSelect ? eventsSelect.value : ''

    if (!seriesId) {
      eventsSection.classList.add('hidden')
      eventsSelect.innerHTML = '<option value="">Select an event...</option>'
      eventsSelect.value = ''
      return
    }

    // Show section
    eventsSection.classList.remove('hidden')

    // If we already have the right options with current value, skip fetch
    if (currentValue && eventsSelect.querySelector(`option[value="${currentValue}"]`)) {
      return
    }

    // Show loading state
    eventsSelect.innerHTML = '<option value="">Loading events...</option>'
    eventsSelect.disabled = true

    // Fetch events for this series
    fetch(`/admin/film_series_events/for_series?series_id=${seriesId}`)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.json()
      })
      .then(events => {
        let options = '<option value="">Select an event...</option>'

        if (events && events.length > 0) {
          events.forEach(event => {
            const date = new Date(event.started_on).toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
              year: 'numeric'
            })
            const selected = String(event.id) === String(currentValue) ? ' selected' : ''
            options += `<option value="${event.id}"${selected}>${event.name} (${date})</option>`
          })
        } else {
          options = '<option value="">No events found for this series</option>'
        }

        eventsSelect.innerHTML = options
        eventsSelect.disabled = false
      })
      .catch(error => {
        console.error('Error loading film series events:', error)
        eventsSelect.innerHTML = '<option value="">Error loading events</option>'
        eventsSelect.disabled = false
      })
  }
}
