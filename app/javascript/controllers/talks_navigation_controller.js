import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="talks-navigation"
export default class extends Controller {
  static targets = ['card']

  connect () {
    this.elementToScroll.scrollIntoView({ block: 'center' })
  }

  setActive (e) {
    this.cardTargets.forEach(card => {
      card.classList.remove('active')
    })
    e.currentTarget.classList.add('active')
  }

  get elementToScroll () {
    return this.hasActiveTarget ? this.activeTarget : this.element
  }
}
