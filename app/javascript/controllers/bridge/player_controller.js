import { BridgeComponent } from '@hotwired/hotwire-native-bridge'
import { patch } from '@rails/request.js'

export default class extends BridgeComponent {
  static component = 'player'

  static values = {
    slug: String,
    url: String,
    title: String,
    subtitle: String,
    poster: String,
    startSeconds: { type: Number, default: 0 },
    progressSeconds: { type: Number, default: 0 },
    durationSeconds: { type: Number, default: 0 },
    watchedTalkPath: String
  }

  connect () {
    super.connect()

    if (this.enabled) {
      this.#present()
    }
  }

  play (event) {
    if (!this.enabled) return

    event.preventDefault()
    event.stopImmediatePropagation()

    this.#present()
  }

  #present () {
    this.send('play', {
      slug: this.slugValue,
      url: this.urlValue,
      title: this.titleValue,
      subtitle: this.subtitleValue,
      poster: this.posterValue,
      startSeconds: this.startSecondsValue,
      progressSeconds: this.progressSecondsValue,
      durationSeconds: this.durationSecondsValue
    }, (message) => {
      this.#syncProgress(message?.data?.progressSeconds)
    })
  }

  #syncProgress (progressSeconds) {
    if (!progressSeconds) return
    if (!this.hasWatchedTalkPathValue) return

    patch(this.watchedTalkPathValue, {
      body: { watched_talk: { progress_seconds: Math.floor(progressSeconds) } },
      responseKind: 'turbo-stream'
    }).catch((error) => {
      console.error('Error syncing native player progress:', error)
    })
  }
}
