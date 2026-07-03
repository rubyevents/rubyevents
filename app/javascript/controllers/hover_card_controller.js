import { Controller } from '@hotwired/stimulus'
import { useResize } from 'stimulus-use'

// Connects to data-controller="hover-card"
export default class extends Controller {
  static targets = ['card']

  connect () {
    useResize(this, { element: document.body })
  }

  reveal () {
    if (!this.hasCardTarget) return
    if (this.revealed) return

    this.revealed = true
    this.cardTarget.hidden = false
    this.scheduleAdjustPosition()
  }

  resize () {
    if (this.revealed) {
      this.cardTarget.style.transform = ''
      this.scheduleAdjustPosition()
    }
  }

  scheduleAdjustPosition () {
    requestAnimationFrame(() => this.adjustPosition())
  }

  adjustPosition () {
    const card = this.cardTarget
    const rect = card.getBoundingClientRect()
    const viewportWidth = window.innerWidth
    const margin = 16

    if (rect.left < margin) {
      const offset = margin - rect.left
      card.style.transform = `translateX(calc(-50% + ${offset}px))`
    } else if (rect.right > viewportWidth - margin) {
      const offset = rect.right - (viewportWidth - margin)
      card.style.transform = `translateX(calc(-50% - ${offset}px))`
    }
  }
}
