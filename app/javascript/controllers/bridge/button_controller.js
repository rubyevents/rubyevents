import { BridgeComponent } from '@hotwired/hotwire-native-bridge'

export default class extends BridgeComponent {
  static component = 'button'
  static targets = ['element']

  connect () {
    super.connect()

    this.send('connect', { title: this.title }, () => {
      this.targetElement.click()
    })
  }

  get targetElement () {
    if (this.hasElementTarget) {
      return this.elementTarget
    }

    return this.element
  }

  get title () {
    return this.bridgeElement.bridgeAttribute('title')
  }
}
