import { Controller } from '@hotwired/stimulus'
import { useIntersection } from 'stimulus-use'

// Connects to data-controller="auto-click"
export default class extends Controller {
  static values = {
    rootMargin: { type: String, default: '400px 0px 0px 0px' }
  }

  initialize () {
    useIntersection(this, { rootMargin: this.rootMarginValue })
  }

  appear () {
    this.element.click()
  }
}
