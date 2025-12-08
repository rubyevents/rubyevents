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

  get splideOptions () {
    return {
      type: 'fade',
      rewind: true,
      perPage: 1,
      autoplay: true,
      speed: 0
    }
  }

  get hiddenSlides () {
    return Array.from(
      this.element.querySelectorAll('.splide__slide > .hidden')
    )
  }
}
