export class IdleDetector {
  constructor (options = {}) {
    this.element = options.element
    this.idleDelay = options.idleDelay || 3000
    this.onIdle = options.onIdle || (() => {})
    this.onActive = options.onActive || (() => {})
    this.checkPlaying = options.checkPlaying || (() => true)

    this.idleTimeout = null
    this.handleMouseMove = this.handleMouseMove.bind(this)
    this.handleMouseLeave = this.handleMouseLeave.bind(this)
  }

  start () {
    if (!this.element) return

    this.element.addEventListener('mousemove', this.handleMouseMove)
    this.element.addEventListener('mouseleave', this.handleMouseLeave)
  }

  stop () {
    if (!this.element) return

    this.element.removeEventListener('mousemove', this.handleMouseMove)
    this.element.removeEventListener('mouseleave', this.handleMouseLeave)
    this.clearTimer()
  }

  handleMouseMove () {
    this.onActive()
    this.resetTimer()
  }

  handleMouseLeave () {
    this.clearTimer()
    if (this.checkPlaying()) {
      this.onIdle()
    }
  }

  resetTimer () {
    this.clearTimer()

    if (this.checkPlaying()) {
      this.idleTimeout = setTimeout(() => {
        this.onIdle()
      }, this.idleDelay)
    }
  }

  clearTimer () {
    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
      this.idleTimeout = null
    }
  }
}
