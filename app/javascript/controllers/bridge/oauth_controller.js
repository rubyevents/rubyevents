import { BridgeComponent } from '@hotwired/hotwire-native-bridge'
import { Turbo } from '@hotwired/turbo-rails'

export default class extends BridgeComponent {
  static component = 'oauth'
  static values = {
    authorizationPath: String,
    exchangePath: String
  }

  disconnect () {
    this.send('disconnect', {})
    super.disconnect()
  }

  signIn () {
    if (!this.enabled) return

    this.send('signIn', { authorizationPath: this.authorizationPathValue }, (message) => {
      this.#exchangeToken(message?.data?.token)
    })
  }

  #exchangeToken (token) {
    if (!token) return

    const url = new URL(this.exchangePathValue, window.location.origin)
    url.searchParams.set('token', token)
    Turbo.visit(url.toString())
  }
}
