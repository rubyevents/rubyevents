import { BridgeComponent } from '@hotwired/hotwire-native-bridge'

export default class extends BridgeComponent {
  static component = 'live-activity'

  static targets = ['button', 'label', 'icon']

  static values = {
    slug: String,
    name: String
  }

  connect () {
    super.connect()

    this.defaultIcon = this.hasIconTarget ? this.iconTarget.innerHTML : ''
    this.defaultLabel = this.hasLabelTarget ? this.labelTarget.textContent : 'Follow live schedule'

    this.refreshStatus()

    this.visibilityHandler = () => {
      if (document.visibilityState === 'visible') this.refreshStatus()
    }

    document.addEventListener('visibilitychange', this.visibilityHandler)
  }

  disconnect () {
    document.removeEventListener('visibilitychange', this.visibilityHandler)
    super.disconnect()
  }

  start () {
    this.markPending()
    this.send('start', { slug: this.slugValue, name: this.nameValue }, (message) => {
      this.applyState(message)
    })
  }

  refreshStatus () {
    this.send('status', { slug: this.slugValue }, (message) => {
      this.applyState(message)
    })
  }

  applyState (message) {
    const data = (message && message.data) || {}

    if (data.active) {
      this.markActive()
    } else {
      this.markInactive()
    }
  }

  markPending () {
    if (this.hasLabelTarget) this.labelTarget.textContent = 'Starting…'

    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.classList.add('opacity-70')
    }
  }

  markActive () {
    if (this.hasIconTarget) this.iconTarget.textContent = '✓'
    if (this.hasLabelTarget) this.labelTarget.textContent = 'Live Activity active'

    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.classList.add('opacity-70', 'cursor-default')
    }
  }

  markInactive () {
    if (this.hasIconTarget) this.iconTarget.innerHTML = this.defaultIcon
    if (this.hasLabelTarget) this.labelTarget.textContent = this.defaultLabel

    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
      this.buttonTarget.classList.remove('opacity-70', 'cursor-default')
    }
  }
}
