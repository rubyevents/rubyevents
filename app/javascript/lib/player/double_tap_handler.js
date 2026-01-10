export class DoubleTapHandler {
  constructor (options = {}) {
    this.element = options.element
    this.onDoubleTapLeft = options.onDoubleTapLeft || (() => {})
    this.onDoubleTapRight = options.onDoubleTapRight || (() => {})
    this.enabledCheck = options.enabledCheck || (() => true)
    this.skipAmount = options.skipAmount || 5
    this.doubleTapThreshold = options.doubleTapThreshold || 300

    this.lastTapTime = 0
    this.lastTapSide = null

    this.handleClick = this.handleClick.bind(this)
  }

  start () {
    if (!this.element) return
    this.element.addEventListener('click', this.handleClick)
  }

  stop () {
    if (!this.element) return
    this.element.removeEventListener('click', this.handleClick)
  }

  handleClick (event) {
    if (!this.enabledCheck()) return
    if (event.target.closest('.custom-player-controls, .custom-player-bottom, button, input')) return

    const now = Date.now()
    const rect = this.element.getBoundingClientRect()
    const clickX = event.clientX - rect.left
    const side = clickX < rect.width / 2 ? 'left' : 'right'

    if (now - this.lastTapTime < this.doubleTapThreshold && side === this.lastTapSide) {
      if (side === 'left') {
        this.onDoubleTapLeft()
        this.showSkipIndicator('left', `-${this.skipAmount}s`)
      } else {
        this.onDoubleTapRight()
        this.showSkipIndicator('right', `+${this.skipAmount}s`)
      }

      this.lastTapTime = 0
      this.lastTapSide = null
    } else {
      this.lastTapTime = now
      this.lastTapSide = side
    }
  }

  showSkipIndicator (side, text) {
    const indicator = document.createElement('div')
    indicator.className = `skip-indicator skip-indicator-${side}`
    indicator.innerHTML = `
      <div class="skip-indicator-icon">
        <svg class="fill-white w-6 h-6" viewBox="0 0 24 24">
          ${side === 'left'
            ? '<path d="M11 18V6l-8.5 6 8.5 6zm.5-6l8.5 6V6l-8.5 6z"/>'
            : '<path d="M4 18l8.5-6L4 6v12zm9-12v12l8.5-6L13 6z"/>'}
        </svg>
      </div>
      <div class="skip-indicator-text">${text}</div>
    `
    this.element.appendChild(indicator)

    setTimeout(() => indicator.remove(), 500)
  }
}
