import { Controller } from '@hotwired/stimulus'
import { PageFlip } from 'page-flip'

export default class extends Controller {
  static targets = ['overlay', 'book', 'stage', 'shift']

  connect () {
    this.pageFlip = null
    this.pointerDownOnBackdrop = false
    this.onKeydown = this.onKeydown.bind(this)
  }

  backdropPointerdown (event) {
    this.pointerDownOnBackdrop = event.target === this.overlayTarget
  }

  disconnect () {
    this.teardown()
  }

  open (event) {
    if (event) event.preventDefault()
    if (this.opening) return

    this.opening = true
    this.overlayTarget.classList.remove('hidden')
    this.overlayTarget.classList.add('flex')

    document.body.style.overflow = 'hidden'
    document.addEventListener('keydown', this.onKeydown)

    this.initPageFlip()

    this.shiftTarget.classList.add('passport-book-shift--centered')

    requestAnimationFrame(() => {
      this.overlayTarget.classList.add('passport-overlay--visible')
      this.stageTarget.classList.add('passport-stage--closed')
      this.stageTarget.getBoundingClientRect()

      requestAnimationFrame(() => {
        this.stageTarget.classList.remove('passport-stage--closed')
        this.stageTarget.classList.add('passport-stage--revealed')
      })
    })

    this.openTimer = setTimeout(() => this.flipOpen(), 1050)
  }

  initPageFlip () {
    if (this.pageFlip) return

    this.pageFlip = new PageFlip(this.bookTarget, {
      width: 360,
      height: 518,
      size: 'stretch',
      minWidth: 280,
      maxWidth: 400,
      minHeight: 403,
      maxHeight: 576,
      showCover: true,
      useMouseEvents: true,
      mobileScrollSupport: false,
      maxShadowOpacity: 0.5,
      flippingTime: 800
    })

    this.pageFlip.loadFromHTML(this.bookTarget.querySelectorAll('.passport-page'))
  }

  flipOpen () {
    if (this.pageFlip && this.pageFlip.getCurrentPageIndex() === 0) {
      this.shiftTarget.classList.remove('passport-book-shift--centered')
      this.pageFlip.flipNext()
    }
  }

  next () {
    this.pageFlip && this.pageFlip.flipNext()
  }

  prev () {
    this.pageFlip && this.pageFlip.flipPrev()
  }

  close (event) {
    if (event) event.preventDefault()

    this.overlayTarget.classList.remove('passport-overlay--visible')
    this.stageTarget.classList.remove('passport-stage--revealed')

    document.body.style.overflow = ''
    document.removeEventListener('keydown', this.onKeydown)

    setTimeout(() => {
      this.overlayTarget.classList.remove('flex')
      this.overlayTarget.classList.add('hidden')
      this.opening = false
    }, 300)
  }

  backdropClose (event) {
    if (this.pointerDownOnBackdrop && event.target === this.overlayTarget) {
      this.close(event)
    }

    this.pointerDownOnBackdrop = false
  }

  onKeydown (event) {
    if (event.key === 'Escape') this.close()
    if (event.key === 'ArrowRight') this.next()
    if (event.key === 'ArrowLeft') this.prev()
  }

  teardown () {
    clearTimeout(this.revealTimer)
    clearTimeout(this.openTimer)

    document.removeEventListener('keydown', this.onKeydown)
    document.body.style.overflow = ''

    if (this.pageFlip) {
      this.pageFlip.destroy()
      this.pageFlip = null
    }
  }
}
