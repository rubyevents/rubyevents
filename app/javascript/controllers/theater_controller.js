import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button']
  static classes = ['active']
  static values = { storageKey: { type: String, default: 'talk-theater-mode' } }

  connect () {
    this.restore()
  }

  restore () {
    this.#apply(window.localStorage.getItem(this.storageKeyValue) === 'true')
  }

  toggle () {
    const active = !this.element.classList.contains(this.activeClass)

    this.#apply(active)
    window.localStorage.setItem(this.storageKeyValue, String(active))
  }

  #apply (active) {
    this.element.classList.toggle(this.activeClass, active)
    this.buttonTargets.forEach((button) => button.setAttribute('aria-pressed', String(active)))
  }
}
