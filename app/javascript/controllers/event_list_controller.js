import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['item', 'poster', 'list', 'topGradient', 'bottomGradient']

  connect () {
    const firstEvent = this.itemTargets[0]

    this.posterTargetFor(firstEvent.dataset.eventId)?.classList.remove('hidden')
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

    const list = this.listTarget
    const scrollTop = list.scrollTop
    const scrollHeight = list.scrollHeight
    const clientHeight = list.clientHeight
    const threshold = 10

    const atTop = scrollTop <= threshold
    const atBottom = scrollTop + clientHeight >= scrollHeight - threshold

    if (this.hasTopGradientTarget) {
      this.topGradientTarget.classList.toggle('md:hidden', atTop)
    }

    if (this.hasBottomGradientTarget) {
      this.bottomGradientTarget.classList.toggle('md:hidden', atBottom)
    }
  }
}
