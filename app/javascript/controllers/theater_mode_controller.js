import { Controller } from '@hotwired/stimulus'
import { IdleDetector } from '~/lib/player/idle_detector'
import { KeyboardShortcuts } from '~/lib/player/keyboard_shortcuts'

export default class extends Controller {
  static targets = ['player', 'content']
  static values = {
    active: { type: Boolean, default: false }
  }

  connect () {
    this.idleDetector = new IdleDetector({
      element: this.element,
      idleDelay: 3000,
      onIdle: () => this.hideTheaterControls(),
      onActive: () => this.showTheaterControls(),
      checkPlaying: () => true
    })

    this.keyboardShortcuts = new KeyboardShortcuts({
      bindings: {
        Escape: () => this.activeValue && this.deactivate(),
        t: () => this.toggle()
      },
      enabledCheck: () => true
    })
    this.keyboardShortcuts.start()
  }

  disconnect () {
    this.keyboardShortcuts?.stop()
    this.idleDetector?.stop()
    this.deactivate()
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
    if (!this.initialized) return

    if (this.activeValue) {
      this.enterTheaterMode()
    } else {
      this.exitTheaterMode()
    }
  }

  get initialized () {
    return !!this.idleDetector
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

    this.idleDetector.start()
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

    this.idleDetector?.stop()
  }

  showTheaterControls () {
    this.element.classList.remove('theater-mode-idle')
  }

  hideTheaterControls () {
    this.element.classList.add('theater-mode-idle')
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
}
