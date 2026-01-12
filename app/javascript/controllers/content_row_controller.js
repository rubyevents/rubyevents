import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['container', 'track', 'prevButton', 'nextButton', 'gradient']

  connect () {
    this.updateButtonVisibility()
  }

  scrollLeft () {
    const scrollAmount = this.cardWidth * 3
    this.containerTarget.scrollBy({ left: -scrollAmount, behavior: 'smooth' })
  }

  scrollRight () {
    const scrollAmount = this.cardWidth * 3
    this.containerTarget.scrollBy({ left: scrollAmount, behavior: 'smooth' })
  }

  handleScroll () {
    this.updateButtonVisibility()
  }

  updateButtonVisibility () {
    const { scrollLeft, scrollWidth, clientWidth } = this.containerTarget
    const isAtStart = scrollLeft <= 10
    const isAtEnd = scrollLeft + clientWidth >= scrollWidth - 10

    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.disabled = isAtStart
      this.prevButtonTarget.classList.toggle('!opacity-0', isAtStart)
    }

    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = isAtEnd
      this.nextButtonTarget.classList.toggle('!opacity-0', isAtEnd)
    }

    if (this.hasGradientTarget) {
      this.gradientTarget.classList.toggle('sm:opacity-0', isAtEnd)
    }
  }

  get cardWidth () {
    const firstCard = this.trackTarget.querySelector(':scope > div')
    return firstCard ? firstCard.offsetWidth + 16 : 320 // 16 = gap-4
  }
}
