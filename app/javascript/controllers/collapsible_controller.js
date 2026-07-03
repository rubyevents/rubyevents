import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['content']
  static values = {
    open: { type: Boolean, default: false }
  }

  connect () {
    this.updateVisibility()
  }

  toggle () {
    this.openValue = !this.openValue
  }

  close () {
    this.openValue = false
  }

  open () {
    this.openValue = true
  }

  openValueChanged () {
    this.updateVisibility()

    if (this.openValue && this.hasContentTarget) {
      requestAnimationFrame(() => {
        this.contentTarget.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      })
    }
  }

  updateVisibility () {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle('hidden', !this.openValue)
    }
  }
}
