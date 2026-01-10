export class KeyboardShortcuts {
  constructor (options = {}) {
    this.bindings = options.bindings || {}
    this.enabledCheck = options.enabledCheck || (() => true)

    this.handleKeydown = this.handleKeydown.bind(this)
  }

  start () {
    document.addEventListener('keydown', this.handleKeydown)
  }

  stop () {
    document.removeEventListener('keydown', this.handleKeydown)
  }

  handleKeydown (event) {
    if (!this.enabledCheck()) return
    if (this.isTyping(event)) return

    const handler = this.bindings[event.key]
    if (handler) {
      event.preventDefault()
      handler(event)
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
