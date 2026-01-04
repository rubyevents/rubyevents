import { Controller } from '@hotwired/stimulus'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

export default class extends Controller {
  static values = {
    markers: Array,
    mode: { type: String, default: 'events' }
  }

  connect () {
    this.map = new maplibregl.Map({
      container: this.element,
      style: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
      center: [0, 20],
      zoom: 1.5
    })

    this.map.on('load', () => {
      this.#loadMarkers()
    })
  }

  #loadMarkers () {
    if (this.markersValue.length === 0) return

    if (this.modeValue === 'venue') {
      this.#loadVenueMarkers()
    } else {
      this.#loadEventMarkers()
    }
  }

  #loadEventMarkers () {
    const bounds = new maplibregl.LngLatBounds()

    this.markersValue.forEach(({ longitude, latitude, events }) => {
      const el = this.#createMarkerElement(events)
      const popup = this.#createPopup(events)

      new maplibregl.Marker({ element: el, anchor: 'center' })
        .setLngLat([longitude, latitude])
        .setPopup(popup)
        .addTo(this.map)

      bounds.extend([longitude, latitude])
    })

    if (this.markersValue.length === 1) {
      this.map.setCenter([this.markersValue[0].longitude, this.markersValue[0].latitude])
      this.map.setZoom(5)
    } else {
      this.map.fitBounds(bounds, {
        padding: 50,
        maxZoom: 10
      })
    }
  }

  #loadVenueMarkers () {
    const bounds = new maplibregl.LngLatBounds()

    this.markersValue.forEach((marker) => {
      const el = this.#createVenueMarkerElement(marker)
      const popup = this.#createVenuePopup(marker)

      new maplibregl.Marker({ element: el, anchor: 'bottom' })
        .setLngLat([marker.longitude, marker.latitude])
        .setPopup(popup)
        .addTo(this.map)

      bounds.extend([marker.longitude, marker.latitude])
    })

    if (this.markersValue.length === 1) {
      this.map.setCenter([this.markersValue[0].longitude, this.markersValue[0].latitude])
      this.map.setZoom(15)
    } else {
      this.map.fitBounds(bounds, {
        padding: 50,
        maxZoom: 15
      })
    }
  }

  disconnect () {
    if (this.map) {
      this.map.remove()
    }
  }

  #createMarkerElement (events) {
    return events.length === 1
      ? this.#html`${this.#singleMarkerTemplate(events[0])}`
      : this.#html`${this.#groupMarkerTemplate(events)}`
  }

  #createPopup (events) {
    return new maplibregl.Popup({
      offset: 25,
      closeButton: false
    }).setDOMContent(this.#html`${this.#popupTemplate(events)}`)
  }

  #html (strings, ...values) {
    const template = document.createElement('template')
    template.innerHTML = String.raw(strings, ...values).trim()
    return template.content.firstElementChild
  }

  #singleMarkerTemplate (event) {
    return `
      <div class="event-marker cursor-pointer">
        <div class="avatar">
          <div class="w-8 rounded-full ring ring-base-100">
            <img src="${event.avatar}" alt="${event.name}" />
          </div>
        </div>
      </div>
    `
  }

  #groupMarkerTemplate (events) {
    const displayEvents = events.slice(0, 3)
    const remaining = events.length - 3

    return `
      <div class="event-marker cursor-pointer">
        <div class="avatar-group -space-x-4 rtl:space-x-reverse">
          ${displayEvents
        .map(
          (event) => `
            <div class="avatar">
              <div class="w-6 rounded-full ring ring-base-100">
                <img src="${event.avatar}" alt="${event.name}" />
              </div>
            </div>
          `
        )
        .join('')}
          ${remaining > 0
        ? `
            <div class="avatar placeholder">
              <div class="bg-neutral text-neutral-content w-6 rounded-full ring ring-base-100">
                <span class="text-xs">+${remaining}</span>
              </div>
            </div>
          `
        : ''
      }
        </div>
      </div>
    `
  }

  #popupTemplate (events) {
    const location = events[0]?.location

    return `
      <div class="flex flex-col max-h-48 overflow-y-auto pr-2 gap-2">
        ${location ? `<div class="text-xs text-gray-500 font-medium">${location}</div>` : ''}
        ${events
        .map(
          (event) => `
          <a href="${event.url}" data-turbo-frame="_top" class="flex items-center gap-2 hover:underline">
            <img src="${event.avatar}" alt="${event.name}" class="w-6 h-6 rounded-full" />
            <span class="font-semibold">${event.name}</span>
          </a>
        `
        )
        .join('')}
      </div>
    `
  }

  #createVenueMarkerElement (marker) {
    const colors = {
      venue: { bg: 'bg-primary', text: 'text-primary-content' },
      hotel: { bg: 'bg-secondary', text: 'text-secondary-content' },
      location: { bg: 'bg-accent', text: 'text-accent-content' }
    }
    const icons = {
      venue: '📍',
      hotel: '🏨',
      location: '📌'
    }
    const { bg, text } = colors[marker.kind] || colors.location
    const icon = icons[marker.kind] || '📌'

    return this.#html`
      <div class="venue-marker cursor-pointer flex flex-col items-center">
        <div class="w-8 h-8 ${bg} ${text} rounded-full flex items-center justify-center shadow-lg border-2 border-white text-base">
          ${icon}
        </div>
      </div>
    `
  }

  #createVenuePopup (marker) {
    return new maplibregl.Popup({
      offset: 25,
      closeButton: false
    }).setDOMContent(this.#html`${this.#venuePopupTemplate(marker)}`)
  }

  #venuePopupTemplate (marker) {
    const kindLabel = marker.location_kind || (marker.kind === 'venue' ? 'Venue' : marker.kind === 'hotel' ? 'Hotel' : 'Location')

    return `
      <div class="flex flex-col gap-1 p-1">
        <div class="text-xs text-gray-500 font-medium uppercase">${kindLabel}</div>
        <div class="font-semibold">${marker.name}</div>
        ${marker.address ? `<div class="text-sm text-gray-600">${marker.address}</div>` : ''}
        ${marker.distance ? `<div class="text-xs text-gray-500">${marker.distance}</div>` : ''}
      </div>
    `
  }
}
