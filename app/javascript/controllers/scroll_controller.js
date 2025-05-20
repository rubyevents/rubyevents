import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['container', 'gradient', 'card']

  connect () {
    this.checkScroll()
  }

  checkScroll () {
    if (this.isAtEnd) {
      this.gradientTarget.classList.add('hidden')
    } else {
      this.gradientTarget.classList.remove('hidden')
    }
  }

  get isAtEnd () {
    return this.containerTarget.scrollLeft + this.containerTarget.offsetWidth >= this.containerTarget.scrollWidth - 1
  }
}
