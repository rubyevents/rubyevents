import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button', 'text', 'status']

  locate () {
    if (!navigator.geolocation) {
      this.showStatus('Geolocation is not supported by your browser')
      return
    }

    this.showStatus('Locating...')
    this.buttonTarget.disabled = true
    this.textTarget.textContent = 'Locating...'

    navigator.geolocation.getCurrentPosition(
      (position) => this.success(position),
      (error) => this.error(error),
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: 300000
      }
    )
  }

  success (position) {
    const { latitude, longitude } = position.coords
    const coordinates = `${latitude},${longitude}`

    this.showStatus('Found your location! Redirecting...')

    window.location.href = `/locations/@${coordinates}`
  }

  error (error) {
    this.buttonTarget.disabled = false
    this.textTarget.textContent = 'Use My Location'

    switch (error.code) {
      case error.PERMISSION_DENIED:
        this.showStatus('Location access was denied. Please enable location permissions in your browser settings.')
        break
      case error.POSITION_UNAVAILABLE:
        this.showStatus('Location information is unavailable.')
        break
      case error.TIMEOUT:
        this.showStatus('The request to get your location timed out.')
        break
      default:
        this.showStatus('An unknown error occurred.')
        break
    }
  }

  showStatus (message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }
}
