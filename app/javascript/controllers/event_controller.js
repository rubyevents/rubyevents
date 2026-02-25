import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="event"
export default class extends Controller {
  static values = {
    name: String
  }

  dispatchEvent (e) {
    this.dispatch(this.nameValue, { prefix: false })
  }
}
