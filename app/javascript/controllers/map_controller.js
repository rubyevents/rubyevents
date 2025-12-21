import { Controller } from '@hotwired/stimulus'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

export default class extends Controller {
  static values = {
    dataUrl: String
  }

  connect () {
    this.map = new maplibregl.Map({
      container: this.element,
      style: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
      center: [0, 20],
      zoom: 1.5
    })

    this.map.on('load', () => {
      this.loadEvents()
    })
  }

  async loadEvents () {
    const response = await fetch(this.dataUrlValue)
    const geojson = await response.json()

    this.markers = []

    geojson.features.forEach((feature) => {
      const { name, url, avatar } = feature.properties
      const [lng, lat] = feature.geometry.coordinates

      const el = document.createElement('div')
      el.className = 'event-marker'
      el.style.width = '32px'
      el.style.height = '32px'
      el.style.borderRadius = '50%'
      el.style.backgroundSize = 'cover'
      el.style.backgroundPosition = 'center'
      el.style.backgroundImage = `url(${avatar})`
      el.style.border = '2px solid white'
      el.style.boxShadow = '0 2px 4px rgba(0,0,0,0.3)'
      el.style.cursor = 'pointer'

      const popup = new maplibregl.Popup({ offset: 20 }).setHTML(
        `<a href="${url}" class="font-semibold hover:underline">${name}</a>`
      )

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat([lng, lat])
        .setPopup(popup)
        .addTo(this.map)

      this.markers.push(marker)
    })
  }

  disconnect () {
    if (this.map) {
      this.map.remove()
    }
  }
}
