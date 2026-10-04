import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static classes = ['active']
  static values = { storageKey: { type: String, default: 'talk-theater-mode' } }

  connect () {
    this.restore()
  }

  restore () {
    this.#apply(this.#stored, { persist: false })
  }

  toggle () {
    this.#apply(!this.#isActive, { persist: true })
  }

  #apply (enabled, { persist }) {
    const active = Boolean(enabled) && this.#isDesktop

    this.element.classList.toggle(this.activeClass, active)

    this.#buttons.forEach((button) => {
      button.setAttribute('aria-pressed', String(active))

      button.querySelectorAll('[data-theater-icon]').forEach((icon) => {
        icon.classList.toggle('hidden', (icon.dataset.theaterIcon === 'active') !== active)
      })

      button.querySelectorAll('[data-theater-label]').forEach((label) => {
        label.textContent = active ? 'Exit theater' : 'Theater'
      })
    })

    if (persist) {
      window.localStorage.setItem(this.storageKeyValue, String(Boolean(enabled)))
    }
  }

  get #buttons () {
    return this.element.querySelectorAll('[data-theater-button]')
  }

  get #isActive () {
    return this.element.classList.contains(this.activeClass)
  }

  get #isDesktop () {
    return window.getComputedStyle(this.element).getPropertyValue('--theater-enabled').trim() === '1'
  }

  get #stored () {
    return window.localStorage.getItem(this.storageKeyValue) === 'true'
  }
}
