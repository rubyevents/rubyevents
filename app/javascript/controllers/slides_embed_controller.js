import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['iframe', 'loading']

  connect () {
    this.fallbackTimeout = setTimeout(() => this.onTimeout(), 15000)
  }

  disconnect () {
    clearTimeout(this.fallbackTimeout)
  }

  loaded () {
    clearTimeout(this.fallbackTimeout)
    this.loadingTarget.hidden = true
    this.iframeTarget.hidden = false
  }

  onTimeout () {
    this.loadingTarget.hidden = true
    this.iframeTarget.hidden = true
  }
}
