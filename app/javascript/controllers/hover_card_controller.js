import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="hover-card"
export default class extends Controller {
  static targets = ['card']

  connect () {
    this.adjustPosition()
    window.addEventListener('resize', this.adjustPosition.bind(this))
  }

  disconnect () {
    window.removeEventListener('resize', this.adjustPosition.bind(this))
  }

  adjustPosition () {
    if (!this.hasCardTarget) return

    const rect = this.element.getBoundingClientRect()
    const cardWidth = this.cardTarget.offsetWidth
    const halfCard = cardWidth / 2
    const avatarCenter = rect.left + rect.width / 2
    const viewportWidth = window.innerWidth

    const spaceOnLeft = avatarCenter
    const spaceOnRight = viewportWidth - avatarCenter

    this.cardTarget.classList.remove('left-0', 'right-0', 'left-1/2', '-translate-x-1/2')

    if (spaceOnLeft < halfCard) {
      this.cardTarget.classList.add('left-0')
    } else if (spaceOnRight < halfCard) {
      this.cardTarget.classList.add('right-0')
    } else {
      this.cardTarget.classList.add('left-1/2', '-translate-x-1/2')
    }
  }
}
