import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['toggle', 'count']
  static values = {
    hideWatched: { type: Boolean, default: false }
  }

  connect () {
    this.updateVisibility()
  }

  toggle () {
    this.hideWatchedValue = !this.hideWatchedValue
  }

  hideWatchedValueChanged () {
    this.updateVisibility()
  }

  get talks () {
    return this.element.querySelectorAll('[data-watched]')
  }

  updateVisibility () {
    let hiddenCount = 0

    this.talks.forEach((talk) => {
      const isWatched = talk.dataset.watched === 'true'

      if (this.hideWatchedValue && isWatched) {
        talk.classList.add('hidden')
        hiddenCount++
      } else {
        talk.classList.remove('hidden')
      }
    })

    if (this.hasCountTarget) {
      this.countTarget.textContent = hiddenCount
      this.countTarget.parentElement.classList.toggle('hidden', hiddenCount === 0)
    }
  }
}
