import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['player', 'content']
  static values = {
    active: { type: Boolean, default: false }
  }

  connect () {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleMouseMove = this.handleMouseMove.bind(this)
    this.handleMouseLeave = this.handleMouseLeave.bind(this)
    document.addEventListener('keydown', this.handleKeydown)

    this.idleTimeout = null
    this.idleDelay = 3000
  }

  disconnect () {
    document.removeEventListener('keydown', this.handleKeydown)
    this.deactivate()
    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
    }
  }

  toggle () {
    this.activeValue = !this.activeValue
  }

  activate () {
    this.activeValue = true
  }

  deactivate () {
    this.activeValue = false
  }

  activeValueChanged () {
    if (this.activeValue) {
      this.enterTheaterMode()
    } else {
      this.exitTheaterMode()
    }
  }

  enterTheaterMode () {
    document.body.classList.add('theater-mode')
    this.element.classList.add('theater-mode-active')

    this.contentTargets.forEach(el => {
      el.classList.add('theater-mode-hidden')
    })

    if (this.hasPlayerTarget) {
      this.playerTarget.classList.add('theater-mode-player')
    }

    this.element.addEventListener('mousemove', this.handleMouseMove)
    this.element.addEventListener('mouseleave', this.handleMouseLeave)
  }

  exitTheaterMode () {
    document.body.classList.remove('theater-mode')
    this.element.classList.remove('theater-mode-active')
    this.element.classList.remove('theater-mode-idle')

    this.contentTargets.forEach(el => {
      el.classList.remove('theater-mode-hidden')
    })

    if (this.hasPlayerTarget) {
      this.playerTarget.classList.remove('theater-mode-player')
    }

    this.element.removeEventListener('mousemove', this.handleMouseMove)
    this.element.removeEventListener('mouseleave', this.handleMouseLeave)

    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
      this.idleTimeout = null
    }
  }

  handleMouseMove () {
    this.showTheaterControls()
    this.resetIdleTimer()
  }

  handleMouseLeave () {
    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
      this.idleTimeout = null
    }
    this.hideTheaterControls()
  }

  resetIdleTimer () {
    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
    }

    this.idleTimeout = setTimeout(() => {
      this.hideTheaterControls()
    }, this.idleDelay)
  }

  showTheaterControls () {
    this.element.classList.remove('theater-mode-idle')
  }

  hideTheaterControls () {
    this.element.classList.add('theater-mode-idle')
  }

  handleKeydown (event) {
    if (event.key === 'Escape' && this.activeValue) {
      this.deactivate()
    }

    if (event.key === 't' && !this.isTyping(event)) {
      this.toggle()
    }
  }

  closeOnBackdrop (event) {
    if (!this.activeValue) return
    if (this.hasPlayerTarget && this.playerTarget.contains(event.target)) return

    const infoBar = this.element.querySelector('.theater-mode-info')
    if (infoBar && infoBar.contains(event.target)) return

    if (event.target === this.element) {
      this.deactivate()
    }
  }

  isTyping (event) {
    const target = event.target
    return target.tagName === 'INPUT' ||
           target.tagName === 'TEXTAREA' ||
           target.tagName === 'SELECT' ||
           target.isContentEditable
  }
}
