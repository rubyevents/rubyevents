export class PlayerConfig {
  constructor (options = {}) {
    this.provider = options.provider
    this.poster = options.poster
    this.startSeconds = options.startSeconds
    this.endSeconds = options.endSeconds
    this.onReady = options.onReady
  }

  build () {
    const providerOptions = {}
    const providerParams = {}
    const controls = false

    if (this.provider === 'youtube') {
      Object.assign(providerOptions, this.youtubeOptions())
      providerParams.mute = 0
    }

    if (this.provider && this.provider !== 'mp4') {
      providerOptions.provider = this.provider
    }

    if (this.startSeconds) {
      providerParams.start = this.startSeconds
      providerParams.start_time = this.startSeconds
    }

    if (this.endSeconds) {
      providerParams.end = this.endSeconds
      providerParams.end_time = this.endSeconds
    }

    return {
      ...providerOptions,
      options: {
        providerParams,
        poster: this.poster,
        controls
      },
      onReady: this.onReady
    }
  }

  youtubeOptions () {
    return {
      controls: 0,
      disablekb: 1,
      fs: 0,
      iv_load_policy: 3,
      rel: 0,
      modestbranding: 1,
      playsinline: 1,
      showinfo: 0,
      cc_load_policy: 0,
      autohide: 1,
      origin: window.location.origin
    }
  }
}
