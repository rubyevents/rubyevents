import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['query']

  connect () {
    this.timeout = null
  }

  submit () {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      const query = this.queryTarget.value.trim()

      if (query.length === 0 || query.length >= 3) {
        this.element.requestSubmit()
      }
    }, 300)
  }

  change () {
    this.element.requestSubmit()
  }
}
