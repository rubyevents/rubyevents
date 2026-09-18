import { Controller } from '@hotwired/stimulus'
import { useMatchMedia } from 'stimulus-use'

export default class extends Controller {
  static targets = ['item', 'caption', 'list', 'topGradient', 'bottomGradient']
  static outlets = ['globe']

  connect () {
    useMatchMedia(this, {
      mediaQueries: { desktop: '(min-width: 768px)' }
    })

    this.updateGradients()
  }

  isDesktop () {
    this.desktop = true
    this.updateGradients()
  }

  notDesktop () {
    this.desktop = false
    this.updateGradients()
  }

  reveal (event) {
    const eventId = event.target.closest('.event-item').dataset.eventId

    this.showCaption(eventId)

    if (this.hasGlobeOutlet) {
      this.globeOutlet.focus(eventId)
    }
  }

  release (event) {
    // Moving between events in the list keeps the focus
    if (event.relatedTarget && this.listTarget.contains(event.relatedTarget)) return

    this.hideCaptions()

    if (this.hasGlobeOutlet) {
      this.globeOutlet.unfocus()
    }
  }

  hideCaptions () {
    this.captionTargets.forEach(caption => caption.classList.add('hidden'))
  }

  hoverMarker (event) {
    this.showCaption(event.detail.slug)
  }

  selectMarker (event) {
    const eventId = event.detail.slug

    this.showCaption(eventId)
    this.itemTargets
      .find(item => item.dataset.eventId === eventId)
      ?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }

  showCaption (eventId) {
    this.captionTargets.forEach(caption => {
      caption.classList.toggle('hidden', caption.dataset.eventId !== eventId)
    })
  }

  updateGradients () {
    if (!this.hasListTarget) return

    if (!this.desktop) {
      if (this.hasTopGradientTarget) this.topGradientTarget.classList.add('hidden')
      if (this.hasBottomGradientTarget) this.bottomGradientTarget.classList.add('hidden')
      return
    }

    const list = this.listTarget
    const scrollTop = list.scrollTop
    const scrollHeight = list.scrollHeight
    const clientHeight = list.clientHeight
    const threshold = 10

    const atTop = scrollTop <= threshold
    const atBottom = scrollTop + clientHeight >= scrollHeight - threshold

    if (this.hasTopGradientTarget) {
      this.topGradientTarget.classList.toggle('hidden', atTop)
    }

    if (this.hasBottomGradientTarget) {
      this.bottomGradientTarget.classList.toggle('hidden', atBottom)
    }
  }
}
