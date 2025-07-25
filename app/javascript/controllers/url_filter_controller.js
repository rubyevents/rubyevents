import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    param: String, // The URL parameter name to update
    removeWhenEmpty: { type: Boolean, default: true } // Whether to remove the param when value is empty
  }

  connect () {
    this.element.addEventListener('change', this.updateUrl.bind(this))
  }

  disconnect () {
    this.element.removeEventListener('change', this.updateUrl.bind(this))
  }

  updateUrl (event) {
    const url = new URL(window.location)
    const value = event.target.value
    const paramName = this.paramValue || event.target.name

    if (!value || (this.removeWhenEmptyValue && value === '')) {
      url.searchParams.delete(paramName)
    } else {
      url.searchParams.set(paramName, value)
    }

    window.location.href = url.toString()
  }
}
