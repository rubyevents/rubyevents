import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['item', 'poster']

  connect () {
    const firstEvent = this.itemTargets[0]

    this.posterTargetFor(firstEvent.dataset.eventId)?.classList.remove('hidden')
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
}
