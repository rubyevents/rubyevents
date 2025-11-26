import { Controller } from '@hotwired/stimulus'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'

export default class extends Controller {
  static values = {
    geojson: Object
  }

  connect() {
    this.map = new maplibregl.Map({
      container: this.element,
      style: 'https://tiles.openfreemap.org/styles/liberty',
      center: [0, 20],
      zoom: 1.5
    })

    this.map.on('load', () => {
      this.map.addSource('events', {
        type: 'geojson',
        data: this.geojsonValue,
        cluster: true,
        clusterMaxZoom: 14,
        clusterRadius: 50
      })

      this.map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'events',
        filter: ['has', 'point_count'],
        paint: {
          'circle-color': [
            'step',
            ['get', 'point_count'],
            '#51bbd6',
            10,
            '#f1f075',
            30,
            '#f28cb1'
          ],
          'circle-radius': [
            'step',
            ['get', 'point_count'],
            20,
            10,
            30,
            30,
            40
          ]
        }
      })

      this.map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'events',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': '{point_count_abbreviated}',
          'text-size': 12
        },
        paint: {
          'text-color': '#ffffff'
        }
      })

      this.map.addLayer({
        id: 'unclustered-point',
        type: 'circle',
        source: 'events',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-color': '#11b4da',
          'circle-radius': 8,
          'circle-stroke-width': 2,
          'circle-stroke-color': '#fff'
        }
      })

      this.map.on('click', 'unclustered-point', (e) => {
        const coordinates = e.features[0].geometry.coordinates.slice()
        const { name, url } = e.features[0].properties

        while (Math.abs(e.lngLat.lng - coordinates[0]) > 180) {
          coordinates[0] += e.lngLat.lng > coordinates[0] ? 360 : -360
        }

        new maplibregl.Popup()
          .setLngLat(coordinates)
          .setHTML(`<a href="${url}" class="font-semibold hover:underline">${name}</a>`)
          .addTo(this.map)
      })

      this.map.on('mouseenter', 'unclustered-point', () => {
        this.map.getCanvas().style.cursor = 'pointer'
      })

      this.map.on('mouseleave', 'unclustered-point', () => {
        this.map.getCanvas().style.cursor = ''
      })

      this.map.on('click', 'clusters', (e) => {
        const features = this.map.queryRenderedFeatures(e.point, {
          layers: ['clusters']
        })
        const clusterId = features[0].properties.cluster_id
        this.map.getSource('events').getClusterExpansionZoom(
          clusterId,
          (err, zoom) => {
            if (err) return

            this.map.easeTo({
              center: features[0].geometry.coordinates,
              zoom
            })
          }
        )
      })

      this.map.on('mouseenter', 'clusters', () => {
        this.map.getCanvas().style.cursor = 'pointer'
      })

      this.map.on('mouseleave', 'clusters', () => {
        this.map.getCanvas().style.cursor = ''
      })
    })
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }
}
