import { Controller } from '@hotwired/stimulus'
import { useMatchMedia } from 'stimulus-use'

export default class extends Controller {
  static targets = ['item', 'poster', 'list', 'topGradient', 'bottomGradient']

  connect () {
    useMatchMedia(this, {
      mediaQueries: { desktop: '(min-width: 768px)' }
    })

    const firstEvent = this.itemTargets[0]

    this.posterTargetFor(firstEvent.dataset.eventId)?.classList.remove('hidden')
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

    this.hidePosters()
    this.posterTargetFor(eventId)?.classList.remove('hidden')
  }

  hidePosters () {
    this.posterTargets.forEach(poster => poster.classList.add('hidden'))
  }

  posterTargetFor (eventId) {
    return this.posterTargets.find(poster => poster.dataset.eventId === eventId)
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
