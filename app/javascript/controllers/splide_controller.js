import { Controller } from '@hotwired/stimulus'

import '@splidejs/splide/css'
import { Splide } from '@splidejs/splide'

export default class extends Controller {
  connect () {
    this.#reset()

    if (!this.splide) {
      this.splide = new Splide(this.element, this.splideOptions)
      this.splide.mount()

      if (this.#shouldUpdateNavbar()) {
        this.splide.on('moved', () => {
          this.#updateNavbarColors()
        })

        this.#updateNavbarColors()
      }

      if (this.#upNextCards.length > 0) {
        this.splide.on('moved', () => {
          this.#updateUpNext()
        })

        this.#updateUpNext()
      }

      if (this.#slideDots.length > 0) {
        this.splide.on('moved', () => {
          this.#updateDots()
        })

        this.#updateDots()
      }
    }

    this.hiddenSlides.forEach(slide =>
      slide.classList.remove('hidden')
    )
  }

  disconnect () {
    this.splide.destroy(true)
    this.splide = undefined
  }

  #reset () {
    this.element.querySelectorAll('.splide__pagination').forEach(slide => slide.remove())
  }

  #shouldUpdateNavbar () {
    return document.body.classList.contains('home-page')
  }

  #updateNavbarColors () {
    const activeSlide = this.element.querySelector('.splide__slide.is-active')
    if (!activeSlide) return

    const featuredColor = activeSlide.dataset.featuredColor
    const featuredBackground = activeSlide.dataset.featuredBackground

    if (!featuredColor || !featuredBackground) return

    document.documentElement.style.setProperty('--featured-color', featuredColor)
    document.documentElement.style.setProperty('--featured-background', featuredBackground)

    const themeColorMeta = document.querySelector('meta[name="theme-color"][data-featured-theme-color]')

    if (themeColorMeta) {
      themeColorMeta.setAttribute('content', featuredBackground)
    }
  }

  goTo (event) {
    this.splide.go(Number(event.currentTarget.dataset.index))
  }

  get #upNextCards () {
    return Array.from(this.element.querySelectorAll('[data-up-next-card]'))
  }

  get #slideDots () {
    return Array.from(this.element.querySelectorAll('[data-slide-dot]'))
  }

  #updateDots () {
    const dots = this.#slideDots
    if (dots.length === 0) return

    const active = this.splide.index

    dots.forEach((dot, index) => {
      dot.classList.toggle('opacity-100', index === active)
      dot.classList.toggle('opacity-40', index !== active)
    })
  }

  #updateUpNext () {
    const cards = this.#upNextCards
    const total = cards.length
    if (total === 0) return

    const active = this.splide.index
    const visible = new Set()

    for (let offset = 1; offset <= total - 1 && visible.size < 3; offset++) {
      visible.add((active + offset) % total)
    }

    cards.forEach((card, index) => {
      card.classList.toggle('hidden', !visible.has(index))
    })
  }

  get splideOptions () {
    return {
      type: 'fade',
      rewind: true,
      perPage: 1,
      autoplay: true,
      speed: 0,
      pagination: false
    }
  }

  get hiddenSlides () {
    return Array.from(
      this.element.querySelectorAll('.splide__slide > .hidden')
    )
  }
}
