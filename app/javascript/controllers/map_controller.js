import { Controller } from '@hotwired/stimulus'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

export default class extends Controller {
  static targets = ['container', 'controls', 'timeFilter']

  static values = {
    markers: Array,
    layers: Array,
    selection: { type: String, default: 'checkbox' },
    mode: { type: String, default: 'events' },
    center: Array,
    zoom: { type: Number, default: 0 },
    bounds: Object
  }

  connect () {
    const hasCenter = this.hasCenterValue && this.centerValue.length === 2
    const hasZoom = this.hasZoomValue && this.zoomValue > 0

    this.markersByLayer = {}
    this.layerGroups = {}
    this.markerDataMap = new Map()
    this.layerVisibility = {}
    this.alwaysVisibleLayers = {}
    this.currentTimeFilter = 'all'

    const mapContainer = this.hasContainerTarget ? this.containerTarget : this.element

    this.map = new maplibregl.Map({
      container: mapContainer,
      style: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
      center: hasCenter ? this.centerValue : [0, 20],
      zoom: hasZoom ? this.zoomValue : 1.5
    })

    this.map.on('load', () => {
      this.#fitToBounds()

      if (this.hasLayersValue && this.layersValue.length > 0) {
        this.#loadLayers()
        this.#initTimeFilter()
      } else {
        this.#loadMarkers()
      }
    })
  }

  #initTimeFilter () {
    if (this.hasTimeFilterTarget) {
      const checkedInput = this.timeFilterTarget.querySelector('input:checked')

      if (checkedInput) {
        this.currentTimeFilter = checkedInput.dataset.timeFilter || 'all'
      }
    }

    this.#applyTimeFilter()
  }

  toggleLayer (event) {
    const layerId = event.target.dataset.layerId
    const visible = event.target.checked

    this.layerVisibility[layerId] = visible

    this.#applyTimeFilter()
    this.#updateButtonState(event.target)
  }

  filterByTime (event) {
    const filter = event.target.dataset.timeFilter
    this.currentTimeFilter = filter

    this.#applyTimeFilter()

    const controls = event.target.closest('[data-map-target="timeFilter"]')

    if (controls) {
      controls.querySelectorAll('input[type="radio"]').forEach((input) => {
        this.#updateButtonState(input)
      })
    }
  }

  #applyTimeFilter () {
    const filter = this.currentTimeFilter || 'all'
    const visibleBounds = new maplibregl.LngLatBounds()
    const layerFilteredCounts = {}
    const isUsersMode = this.modeValue === 'users'

    let hasVisibleMarkers = false

    Object.entries(this.markersByLayer).forEach(([layerId, markers]) => {
      layerFilteredCounts[layerId] = 0

      const layerData = this.layersValue.find((l) => l.id === layerId)
      const layerVisible = this.layerVisibility[layerId] !== false
      const alwaysVisible = layerData?.alwaysVisible === true

      markers.forEach((marker) => {
        const markerData = this.markerDataMap.get(marker)
        if (!markerData) return

        const items = isUsersMode
          ? (markerData.users || [])
          : this.#filterEventsByTime(markerData.events, filter)

        const isVisible = (layerVisible || alwaysVisible) && items.length > 0

        layerFilteredCounts[layerId] += items.length

        const element = marker.getElement()
        element.style.display = isVisible ? '' : 'none'

        if (markerData.popup && items.length > 0) {
          const popupContent = isUsersMode
            ? this.#userPopupTemplate(items)
            : this.#popupTemplate(items)
          markerData.popup.setDOMContent(this.#html`${popupContent}`)
        }

        if (isVisible) {
          const newElement = isUsersMode
            ? this.#createUserMarkerElement(items)
            : this.#createMarkerElement(items)
          element.innerHTML = newElement.innerHTML

          if (layerVisible) {
            visibleBounds.extend([markerData.longitude, markerData.latitude])
            hasVisibleMarkers = true
          }
        }
      })
    })

    this.#updateLayerBadgeCounts(layerFilteredCounts)

    if (hasVisibleMarkers) {
      this.#fitToVisibleBounds(visibleBounds)
    }
  }

  #updateLayerBadgeCounts (counts) {
    if (this.hasControlsTarget) {
      this.controlsTarget.querySelectorAll('input[data-layer-id]').forEach((input) => {
        const layerId = input.dataset.layerId
        const count = counts[layerId] || 0
        const badge = input.closest('label')?.querySelector('.badge')

        if (badge) {
          badge.textContent = count
        }
      })
    }
  }

  #filterEventsByTime (events, filter) {
    if (filter === 'all') return events
    if (filter === 'upcoming') return events.filter((e) => e.upcoming)
    if (filter === 'past') return events.filter((e) => !e.upcoming)

    return events
  }

  #fitToVisibleBounds (bounds) {
    if (!bounds.isEmpty()) {
      const sw = bounds.getSouthWest()
      const ne = bounds.getNorthEast()

      if (sw.lng === ne.lng && sw.lat === ne.lat) {
        this.map.easeTo({
          center: [sw.lng, sw.lat],
          zoom: 5,
          duration: 500
        })
      } else {
        this.map.fitBounds(bounds, {
          padding: 50,
          maxZoom: 10,
          duration: 500
        })
      }
    }
  }

  selectLayer (event) {
    const selectedLayerId = event.target.dataset.layerId
    const selectedGroup = this.layerGroups[selectedLayerId]

    Object.keys(this.markersByLayer).forEach((layerId) => {
      const layerGroup = this.layerGroups[layerId]

      if (layerGroup === selectedGroup) {
        this.layerVisibility[layerId] = layerId === selectedLayerId
      }
    })

    this.#applyTimeFilter()

    const selectedLayer = this.layersValue.find((layer) => layer.id === selectedLayerId)
    const selectedMarkers = this.markersByLayer[selectedLayerId] || []

    const hasVisibleMarkers = selectedMarkers.some((marker) => {
      const element = marker.getElement()
      return element.style.display !== 'none'
    })

    if (!hasVisibleMarkers) {
      if (selectedLayer?.cityPin) {
        this.map.easeTo({
          center: [selectedLayer.cityPin.longitude, selectedLayer.cityPin.latitude],
          zoom: 10,
          duration: 500
        })
      } else if (selectedLayer?.bounds) {
        this.#fitToLayerBounds(selectedLayer.bounds)
      }
    }

    const controls = event.target.closest('[data-map-target="controls"]')

    if (controls) {
      controls.querySelectorAll('input[type="radio"]').forEach((input) => {
        this.#updateButtonState(input)
      })
    }
  }

  #fitToLayerBounds (bounds) {
    if (!bounds?.southwest || !bounds?.northeast) return

    this.map.fitBounds(
      [bounds.southwest, bounds.northeast],
      { padding: 20, duration: 500 }
    )
  }

  #updateLayerVisibility (layerId, visible) {
    const markers = this.markersByLayer[layerId] || []

    markers.forEach((marker) => {
      const element = marker.getElement()

      element.style.display = visible ? '' : 'none'
    })
  }

  #updateButtonState (input) {
    const label = input.closest('label')
    if (!label) return

    const badge = label.querySelector('.badge')

    if (input.checked) {
      label.classList.add('btn-primary', 'text-primary-content')
      label.classList.remove('btn-ghost')

      if (badge) {
        badge.classList.add('bg-white', 'text-primary')
        badge.classList.remove('badge-ghost')
      }
    } else {
      label.classList.remove('btn-primary', 'text-primary-content')
      label.classList.add('btn-ghost')

      if (badge) {
        badge.classList.remove('bg-white', 'text-primary')
        badge.classList.add('badge-ghost')
      }
    }
  }

  #loadLayers () {
    const hasCenter = this.hasCenterValue && this.centerValue.length === 2
    const hasZoom = this.hasZoomValue && this.zoomValue > 0
    const hasBounds = this.hasBoundsValue && this.boundsValue.southwest && this.boundsValue.northeast
    const visibleBounds = new maplibregl.LngLatBounds()

    let visibleMarkerCount = 0
    let visibleLayerWithBounds = null

    this.alwaysVisibleLayers = {}
    this.cityPinMarker = null

    this.layersValue.forEach((layer) => {
      const layerId = layer.id
      const visible = layer.visible !== false
      const alwaysVisible = layer.alwaysVisible === true

      this.markersByLayer[layerId] = []
      this.layerGroups[layerId] = layer.group || null
      this.layerVisibility[layerId] = visible
      this.alwaysVisibleLayers[layerId] = alwaysVisible

      if (visible && layer.bounds) {
        visibleLayerWithBounds = layer.bounds
      }

      if (layer.cityPin) {
        const { longitude, latitude, name } = layer.cityPin
        const element = this.#createCityPinElement(name)
        const popup = this.#createCityPinPopup(name)

        this.cityPinMarker = new maplibregl.Marker({ element, anchor: 'bottom' })
          .setLngLat([longitude, latitude])
          .setPopup(popup)
          .addTo(this.map)
      }

      layer.markers.forEach((markerData) => {
        const { longitude, latitude, events, users } = markerData
        const items = this.modeValue === 'users' ? users : events

        const element = this.modeValue === 'users'
          ? this.#createUserMarkerElement(items)
          : this.#createMarkerElement(items)

        const popup = this.modeValue === 'users'
          ? this.#createUserPopup(items)
          : this.#createPopup(items)

        if (!visible && !alwaysVisible) {
          element.style.display = 'none'
        }

        const marker = new maplibregl.Marker({ element, anchor: 'center' })
          .setLngLat([longitude, latitude])
          .setPopup(popup)
          .addTo(this.map)

        this.markersByLayer[layerId].push(marker)
        this.markerDataMap.set(marker, { items, events, users, longitude, latitude, popup })

        if (visible) {
          visibleBounds.extend([longitude, latitude])
          visibleMarkerCount++
        }
      })
    })

    if (hasBounds || (hasCenter && hasZoom)) return

    const cityPinLayer = this.layersValue.find((l) => l.cityPin)
    const cityPin = cityPinLayer?.cityPin

    if (visibleMarkerCount === 1) {
      const visibleLayer = this.layersValue.find((l) => l.visible !== false && l.markers.length > 0)

      if (visibleLayer) {
        const firstMarker = visibleLayer.markers[0]
        this.map.setCenter([firstMarker.longitude, firstMarker.latitude])
        this.map.setZoom(5)
      }
    } else if (visibleMarkerCount > 1) {
      this.map.fitBounds(visibleBounds, {
        padding: 50,
        maxZoom: 10
      })
    } else if (visibleMarkerCount === 0 && cityPin) {
      this.map.setCenter([cityPin.longitude, cityPin.latitude])
      this.map.setZoom(10)
    } else if (visibleMarkerCount === 0 && visibleLayerWithBounds) {
      this.#fitToLayerBounds(visibleLayerWithBounds)
    }
  }

  #fitToBounds () {
    if (!this.hasBoundsValue || !this.boundsValue.southwest || !this.boundsValue.northeast) return

    this.map.fitBounds(
      [this.boundsValue.southwest, this.boundsValue.northeast],
      { padding: 20, animate: false }
    )
  }

  #loadMarkers () {
    if (this.markersValue.length === 0) return

    if (this.modeValue === 'venue') {
      this.#loadVenueMarkers()
    } else if (this.modeValue === 'users') {
      this.#loadUserMarkers()
    } else {
      this.#loadEventMarkers()
    }
  }

  #loadEventMarkers () {
    const hasCenter = this.hasCenterValue && this.centerValue.length === 2
    const hasZoom = this.hasZoomValue && this.zoomValue > 0
    const hasBounds = this.hasBoundsValue && this.boundsValue.southwest && this.boundsValue.northeast

    this.markersValue.forEach(({ longitude, latitude, events }) => {
      const element = this.#createMarkerElement(events)
      const popup = this.#createPopup(events)

      new maplibregl.Marker({ element, anchor: 'center' })
        .setLngLat([longitude, latitude])
        .setPopup(popup)
        .addTo(this.map)
    })

    if (hasBounds || (hasCenter && hasZoom)) return

    const bounds = new maplibregl.LngLatBounds()

    this.markersValue.forEach(({ longitude, latitude }) => {
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
      const element = this.#createVenueMarkerElement(marker)
      const popup = this.#createVenuePopup(marker)

      new maplibregl.Marker({ element, anchor: 'bottom' })
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

  #loadUserMarkers () {
    const hasCenter = this.hasCenterValue && this.centerValue.length === 2
    const hasZoom = this.hasZoomValue && this.zoomValue > 0
    const hasBounds = this.hasBoundsValue && this.boundsValue.southwest && this.boundsValue.northeast

    this.markersValue.forEach(({ longitude, latitude, users }) => {
      const element = this.#createUserMarkerElement(users)
      const popup = this.#createUserPopup(users)

      new maplibregl.Marker({ element, anchor: 'center' })
        .setLngLat([longitude, latitude])
        .setPopup(popup)
        .addTo(this.map)
    })

    if (hasBounds || (hasCenter && hasZoom)) return

    const bounds = new maplibregl.LngLatBounds()

    this.markersValue.forEach(({ longitude, latitude }) => {
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

  #createCityPinElement (name) {
    return this.#html`
      <div class="city-pin cursor-pointer flex flex-col items-center">
        <svg width="24" height="36" viewBox="0 0 24 36" fill="none" xmlns="http://www.w3.org/2000/svg" class="drop-shadow-lg">
          <path d="M12 0C5.373 0 0 5.373 0 12c0 9 12 24 12 24s12-15 12-24c0-6.627-5.373-12-12-12z" fill="#DC2626"/>
          <circle cx="12" cy="12" r="5" fill="white"/>
        </svg>
      </div>
    `
  }

  #createCityPinPopup (name) {
    return new maplibregl.Popup({
      offset: 25,
      closeButton: false
    }).setDOMContent(this.#html`
      <div class="flex flex-col gap-1 p-1">
        <div class="font-semibold">${name}</div>
      </div>
    `)
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

  #createUserMarkerElement (users) {
    return users.length === 1
      ? this.#html`${this.#singleUserMarkerTemplate(users[0])}`
      : this.#html`${this.#groupUserMarkerTemplate(users)}`
  }

  #createUserPopup (users) {
    return new maplibregl.Popup({
      offset: 25,
      closeButton: false
    }).setDOMContent(this.#html`${this.#userPopupTemplate(users)}`)
  }

  #singleUserMarkerTemplate (user) {
    return `
      <div class="user-marker cursor-pointer">
        <div class="avatar">
          <div class="w-8 rounded-full ring ring-base-100 ${user.speaker ? 'ring-primary' : ''}">
            <img src="${user.avatar}" alt="${user.name}" />
          </div>
        </div>
      </div>
    `
  }

  #groupUserMarkerTemplate (users) {
    const displayUsers = users.slice(0, 3)
    const remaining = users.length - 3

    return `
      <div class="user-marker cursor-pointer">
        <div class="avatar-group -space-x-4 rtl:space-x-reverse">
          ${displayUsers
        .map(
          (user) => `
            <div class="avatar">
              <div class="w-6 rounded-full ring ring-base-100">
                <img src="${user.avatar}" alt="${user.name}" />
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

  #userPopupTemplate (users) {
    const location = users[0]?.location

    return `
      <div class="flex flex-col max-h-48 overflow-y-auto pr-2 gap-2">
        ${location ? `<div class="text-xs text-gray-500 font-medium">${location}</div>` : ''}
        ${users
        .map(
          (user) => `
          <a href="${user.url}" data-turbo-frame="_top" class="flex items-center gap-2 hover:underline">
            <img src="${user.avatar}" alt="${user.name}" class="w-6 h-6 rounded-full" />
            <span class="font-semibold">${user.name}</span>
            ${user.speaker ? '<span class="badge badge-xs badge-primary">speaker</span>' : ''}
          </a>
        `
        )
        .join('')}
      </div>
    `
  }
}
