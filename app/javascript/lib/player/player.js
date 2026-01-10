import Vlitejs from 'vlitejs'
import YouTube from 'vlitejs/providers/youtube.js'
import Vimeo from 'vlitejs/providers/vimeo.js'
import { patch } from '@rails/request.js'

import { PlayerConfig } from './player_config'

Vlitejs.registerProvider('youtube', YouTube)
Vlitejs.registerProvider('vimeo', Vimeo)

export class Player {
  constructor (options = {}) {
    this.element = options.element
    this.provider = options.provider
    this.poster = options.poster
    this.startSeconds = options.startSeconds
    this.endSeconds = options.endSeconds
    this.durationSeconds = options.durationSeconds || 0
    this.progressSeconds = options.progressSeconds || 0
    this.watchedTalkPath = options.watchedTalkPath
    this.currentUserPresent = options.currentUserPresent || false

    this.onReady = options.onReady || (() => {})
    this.onPlay = options.onPlay || (() => {})
    this.onPause = options.onPause || (() => {})
    this.onEnded = options.onEnded || (() => {})
    this.onTimeUpdate = options.onTimeUpdate || (() => {})
    this.onDurationChange = options.onDurationChange || (() => {})
    this.onProgress = options.onProgress || (() => {})

    this.vlitejs = null
    this.ready = false
    this.playing = false
    this.muted = false
    this.playbackRateOptions = [1, 1.25, 1.5, 1.75, 2]
    this.currentPlaybackRateIndex = 0
    this.progressInterval = null
    this.uiUpdateInterval = null
  }

  init () {
    if (!this.element) return

    const config = new PlayerConfig({
      provider: this.provider,
      poster: this.poster,
      startSeconds: this.startSeconds,
      endSeconds: this.endSeconds,
      onReady: this.handlePlayerReady.bind(this)
    })

    this.vlitejs = new Vlitejs(this.element, config.build())
  }

  handlePlayerReady (player) {
    this.ready = true
    this.vlitejs = player

    if (this.provider === 'youtube') {
      const overlay = player.elements.container.querySelector('.v-overlay')
      if (overlay) overlay.remove()
      this.setupYouTubeEvents(player)
    }

    if (this.provider === 'vimeo') {
      this.setupVimeoEvents(player)
    }

    if (this.provider === 'mp4' && player.media) {
      this.setupMP4Events(player)
    } else {
      this.fetchExternalPlayerDuration()
    }

    if (this.progressSeconds > 0 && !this.isFullyWatched()) {
      this.seekTo(this.progressSeconds)
    }

    this.onReady(this)
  }

  setupYouTubeEvents (player) {
    if (!player.instance) return

    player.instance.addEventListener('onStateChange', (event) => {
      const STATES = { ENDED: 0, PLAYING: 1, PAUSED: 2 }

      if (event.data === STATES.PLAYING) {
        this.setPlayingState(true)
        this.startProgressTracking()
      } else if (event.data === STATES.PAUSED) {
        this.setPlayingState(false)
        this.handlePause()
      } else if (event.data === STATES.ENDED) {
        this.setPlayingState(false)
        this.handleEnded()
      }
    })
  }

  setupVimeoEvents (player) {
    player.instance.on('play', () => {
      this.setPlayingState(true)
      this.startProgressTracking()
    })

    player.instance.on('pause', () => {
      this.setPlayingState(false)
      this.handlePause()
    })

    player.instance.on('ended', () => {
      this.setPlayingState(false)
      this.handleEnded()
    })
  }

  setupMP4Events (player) {
    player.media.addEventListener('play', () => {
      this.setPlayingState(true)
      this.startProgressTracking()
    })

    player.media.addEventListener('pause', () => {
      this.setPlayingState(false)
      this.handlePause()
    })

    player.media.addEventListener('ended', () => {
      this.setPlayingState(false)
      this.handleEnded()
    })

    player.media.addEventListener('loadedmetadata', () => {
      this.setDuration(player.media.duration)
    })

    if (player.media.duration && !isNaN(player.media.duration)) {
      this.setDuration(player.media.duration)
    }
  }

  setPlayingState (playing) {
    this.playing = playing

    if (playing) {
      this.startUIUpdateLoop()
      this.onPlay()
    } else {
      this.stopUIUpdateLoop()
    }
  }

  async handlePause () {
    this.stopProgressTracking()
    const currentTime = await this.getCurrentTime()
    this.progressSeconds = Math.floor(currentTime)
    this.updateWatchedProgress(this.progressSeconds)
    this.onPause()
  }

  handleEnded () {
    this.stopProgressTracking()
    if (this.durationSeconds > 0) {
      this.progressSeconds = this.durationSeconds
      this.updateWatchedProgress(this.durationSeconds)
    }
    this.onEnded()
  }

  play () {
    if (!this.ready) return
    this.vlitejs.play()
    if (this.vlitejs.unMute) {
      this.vlitejs.unMute()
    }
  }

  pause () {
    if (!this.ready) return
    this.vlitejs.pause()
  }

  togglePlay () {
    if (!this.ready) return

    if (this.playing) {
      this.pause()
    } else {
      this.play()
    }
  }

  async getCurrentTime () {
    try {
      if (this.provider === 'mp4' && this.vlitejs.media) {
        return this.vlitejs.media.currentTime
      }
      return await this.vlitejs.instance.getCurrentTime()
    } catch (error) {
      console.error('Error getting current time:', error)
      return 0
    }
  }

  async getDuration () {
    try {
      if (this.provider === 'mp4' && this.vlitejs.media) {
        return this.vlitejs.media.duration || this.durationSeconds || 0
      }
      if (this.vlitejs.instance?.getDuration) {
        return await this.vlitejs.instance.getDuration()
      }
    } catch (e) {}
    return this.durationSeconds || 0
  }

  setDuration (duration) {
    if (!duration || isNaN(duration)) return
    this.durationSeconds = duration
    this.onDurationChange(duration)
  }

  async fetchExternalPlayerDuration () {
    await new Promise(resolve => setTimeout(resolve, 500))

    try {
      if (this.vlitejs?.instance?.getDuration) {
        const duration = await this.vlitejs.instance.getDuration()
        if (duration && duration > 0) {
          this.setDuration(duration)
        }
      }
    } catch (e) {}
  }

  seekTo (time) {
    if (!this.ready) return

    if (this.provider === 'mp4' && this.vlitejs.media) {
      this.vlitejs.media.currentTime = time
    } else {
      this.vlitejs.seekTo(time)
    }

    this.progressSeconds = Math.floor(time)
    this.updateWatchedProgress(this.progressSeconds)
  }

  async skipBy (seconds) {
    const currentTime = await this.getCurrentTime()
    const newTime = Math.max(0, currentTime + seconds)

    if (this.provider === 'mp4' && this.vlitejs.media) {
      this.vlitejs.media.currentTime = newTime
    } else {
      this.vlitejs.seekTo(newTime)
    }
  }

  skipForward (seconds = 10) {
    this.skipBy(seconds)
  }

  skipBackward (seconds = 10) {
    this.skipBy(-seconds)
  }

  toggleMute () {
    if (!this.ready) return

    if (this.provider === 'mp4' && this.vlitejs.media) {
      this.vlitejs.media.muted = !this.vlitejs.media.muted
      this.muted = this.vlitejs.media.muted
    } else if (this.vlitejs.instance) {
      if (this.muted) {
        this.vlitejs.unMute?.() || this.vlitejs.instance.unMute?.()
        this.muted = false
      } else {
        this.vlitejs.mute?.() || this.vlitejs.instance.mute?.()
        this.muted = true
      }
    }

    return this.muted
  }

  setVolume (volume) {
    if (!this.ready || !this.vlitejs.instance) return

    if (this.vlitejs.instance.setVolume) {
      this.vlitejs.instance.setVolume(volume)
    }

    this.muted = volume === 0
    return this.muted
  }

  cyclePlaybackRate () {
    if (!this.ready) return 1

    this.currentPlaybackRateIndex = (this.currentPlaybackRateIndex + 1) % this.playbackRateOptions.length
    const rate = this.playbackRateOptions[this.currentPlaybackRateIndex]

    if (this.provider === 'mp4' && this.vlitejs.media) {
      this.vlitejs.media.playbackRate = rate
    } else if (this.vlitejs.instance?.setPlaybackRate) {
      this.vlitejs.instance.setPlaybackRate(rate)
    }

    return rate
  }

  get currentPlaybackRate () {
    return this.playbackRateOptions[this.currentPlaybackRateIndex]
  }

  isFullyWatched () {
    if (!this.durationSeconds || this.durationSeconds <= 0) return false
    return this.progressSeconds >= this.durationSeconds - 5
  }

  async startProgressTracking () {
    if (this.progressInterval) return
    if (!this.currentUserPresent) return

    const currentTime = await this.getCurrentTime()
    this.progressSeconds = Math.floor(currentTime)
    this.updateWatchedProgress(this.progressSeconds)

    this.progressInterval = setInterval(async () => {
      if (this.watchedTalkPath) {
        const currentTime = await this.getCurrentTime()
        this.progressSeconds = Math.floor(currentTime)
        this.updateWatchedProgress(this.progressSeconds)
      }
    }, 5000)
  }

  stopProgressTracking () {
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
      this.progressInterval = null
    }
  }

  updateWatchedProgress (progressSeconds) {
    if (!this.watchedTalkPath) return
    if (!this.currentUserPresent) return

    patch(this.watchedTalkPath, {
      body: {
        watched_talk: {
          progress_seconds: progressSeconds
        }
      },
      responseKind: 'turbo-stream'
    }).catch(error => {
      console.error('Error updating watch progress:', error)
    })

    this.onProgress(progressSeconds, this.durationSeconds)
  }

  startUIUpdateLoop () {
    if (this.uiUpdateInterval) return

    this.uiUpdateInterval = setInterval(async () => {
      const currentTime = await this.getCurrentTime()
      const duration = this.durationSeconds || await this.getDuration()

      if (duration > 0) {
        const percent = (currentTime / duration) * 100
        this.onTimeUpdate(currentTime, duration, percent)
      }
    }, 250)
  }

  stopUIUpdateLoop () {
    if (this.uiUpdateInterval) {
      clearInterval(this.uiUpdateInterval)
      this.uiUpdateInterval = null
    }
  }

  destroy () {
    this.stopProgressTracking()
    this.stopUIUpdateLoop()
  }

  formatTime (seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
}
