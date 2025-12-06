import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { delay: Number }
  static targets = ['input']

  connect () {
    this.timeout = null

    if (this.hasInputTarget) {
      this.inputTarget.focus()
      this.inputTarget.selectionStart = this.inputTarget.selectionEnd = this.inputTarget.value.length
    }
  }

  search () {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 800)
  }
}
