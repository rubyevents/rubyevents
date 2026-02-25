import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['toggable', 'toggle']

  static values = {
    hideText: {
      type: String,
      default: 'hide'
    }
  }

  connect () {
    if (this.hasToggleTarget) {
      this.toggleText = this.toggleTarget.textContent
    }
  }

  toggle () {
    this.toggleTarget.textContent = this.nextToggleText
    this.toggableTargets.forEach(toggable => toggable.classList.toggle('hidden'))
  }

  get nextToggleText () {
    return (this.toggleTarget.textContent === this.toggleText)
      ? this.hideTextValue
      : this.toggleText
  }
}
