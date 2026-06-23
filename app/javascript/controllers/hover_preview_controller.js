import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['card', 'preview']
  static values = { delay: { type: Number, default: 350 } }

  connect () {
    this.onScroll = () => this.hide(true)
  }

  disconnect () {
    this.#clearTimers()
    this.#detachScroll()
  }

  enter () {
    if (!this.#enabled) return

    clearTimeout(this.hideTimer)
    clearTimeout(this.cleanupTimer)
    this.showTimer = setTimeout(() => this.show(), this.delayValue)
  }

  leave () {
    clearTimeout(this.showTimer)
    this.hideTimer = setTimeout(() => this.hide(), 80)
  }

  show () {
    if (!this.hasPreviewTarget) return

    const preview = this.previewTarget
    preview.classList.remove('hidden')
    preview.style.opacity = '1'

    const fromCard = this.#layout()
    preview.style.transition = 'none'
    preview.style.transform = fromCard

    preview.getBoundingClientRect()

    preview.style.transition = 'transform 220ms cubic-bezier(0.22, 1, 0.36, 1)'
    preview.style.transform = 'none'

    window.addEventListener('scroll', this.onScroll, { passive: true, capture: true })
  }

  hide (immediate = false) {
    if (!this.hasPreviewTarget) return

    const preview = this.previewTarget
    this.#detachScroll()

    if (immediate || preview.classList.contains('hidden')) {
      this.#reset()
      return
    }

    preview.style.transition = 'transform 160ms ease-in, opacity 160ms ease-in'
    preview.style.transform = this.#layout()
    preview.style.opacity = '0'

    clearTimeout(this.cleanupTimer)
    this.cleanupTimer = setTimeout(() => this.#reset(), 160)
  }

  #layout () {
    const card = this.cardTarget.getBoundingClientRect()
    const preview = this.previewTarget
    const scale = 1.3
    const width = Math.round(card.width * scale)

    let left = card.left - (width - card.width) / 2
    left = Math.max(8, Math.min(left, window.innerWidth - width - 8))

    preview.style.position = 'fixed'
    preview.style.width = `${width}px`
    preview.style.left = `${Math.round(left)}px`
    preview.style.zIndex = '50'
    preview.style.transformOrigin = 'top left'

    const height = preview.offsetHeight
    let top = card.top - (card.height * (scale - 1)) / 2
    top = Math.min(top, window.innerHeight - height - 8)
    top = Math.max(8, top)
    preview.style.top = `${Math.round(top)}px`

    const s = card.width / width
    const tx = card.left - left
    const ty = card.top - top
    return `translate(${tx}px, ${ty}px) scale(${s})`
  }

  #reset () {
    const preview = this.previewTarget
    preview.classList.add('hidden')
    preview.style.transition = ''
    preview.style.transform = ''
    preview.style.opacity = ''
  }

  get #enabled () {
    return window.matchMedia('(min-width: 1024px) and (hover: hover)').matches
  }

  #detachScroll () {
    window.removeEventListener('scroll', this.onScroll, { capture: true })
  }

  #clearTimers () {
    clearTimeout(this.showTimer)
    clearTimeout(this.hideTimer)
    clearTimeout(this.cleanupTimer)
  }
}
