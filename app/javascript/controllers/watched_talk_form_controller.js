import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['watchedAt', 'submitButton']
  static values = {
    talkDate: String,
    autoSubmit: { type: Boolean, default: false }
  }

  selectWatchedOn (event) {
    const selectedValue = event.target.value

    if (selectedValue === 'in_person' && this.hasTalkDateValue && this.talkDateValue) {
      this.watchedAtTarget.value = this.talkDateValue
    }

    this.autoSubmit()
  }

  select () {
    this.autoSubmit()
  }

  autoSubmit () {
    if (this.autoSubmitValue) {
      this.element.requestSubmit()
    }
  }
}
