import { Controller } from '@hotwired/stimulus'
import { useIntersection } from 'stimulus-use'

// Connects to data-controller="lazy-loading"
export default class extends Controller {
  static values = {
    src: String,
    rootMargin: { type: String, default: '300px 0px 0px 0px' }
  }

  initialize () {
    useIntersection(this, { rootMargin: this.rootMarginValue })
  }

  appear () {
    this.element.setAttribute('src', this.srcValue)
  }
}
