import { Controller } from '@hotwired/stimulus'

// this controller is used to scroll into the center to the active target
// if no active target is found, it will scroll into the center of the element
// Connects to data-controller="scroll-into-view"
export default class extends Controller {
  static targets = ['active']

  connect () {
    this.elementToScroll.scrollIntoView({ block: 'center' })
  }

  get elementToScroll () {
    return this.hasActiveTarget ? this.activeTarget : this.element
  }
}
