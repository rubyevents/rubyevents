import { Controller } from '@hotwired/stimulus'
import { useIntersection } from 'stimulus-use'
import Vlitejs from 'vlitejs'
import YouTube from 'vlitejs/providers/youtube.js'
import Vimeo from 'vlitejs/providers/vimeo.js'
import { patch } from '@rails/request.js'

Vlitejs.registerProvider('youtube', YouTube)
Vlitejs.registerProvider('vimeo', Vimeo)

export default class extends Controller {
  static values = {
    poster: String,
    src: String,
    provider: String,
    startSeconds: Number,
    endSeconds: Number,
    watchedTalkPath: String,
    currentUserPresent: { default: false, type: Boolean }
  }

  static targets = ['player', 'playerWrapper']
  playbackRateOptions = [1, 1.25, 1.5, 1.75, 2]

  initialize () {
    useIntersection(this, { element: this.playerWrapperTarget, threshold: 0.5, visibleAttribute: null })
  }

  connect () {
    this.init()
  }

  // methods

  init () {
    if (this.isPreview) return
    if (!this.hasPlayerTarget) return

    this.player = new Vlitejs(this.playerTarget, this.options)
  }

  get options () {
    const providerOptions = {}
    const providerParams = {}
    // Youtube videos have their own controls, so we need to hide the Vlitejs controls
    let controls = true

    // Hide the Vlitejs controls if the video is a Youtube video
    providerParams.controls = !controls

    if (this.hasProviderValue && this.providerValue === 'youtube') {
      // Set YT rel to 0 to show related videos from the respective channel
      providerOptions.rel = 0
      providerOptions.autohide = 0
      // Show YT controls
      providerOptions.controls = 1
      // Hide the Vlitejs controls
      controls = false
    }
    if (this.hasProviderValue && this.providerValue !== 'mp4') {
      providerOptions.provider = this.providerValue
    }

    if (this.hasStartSecondsValue) {
      providerParams.start = this.startSecondsValue
      providerParams.start_time = this.startSecondsValue
    }

    if (this.hasEndSecondsValue) {
      providerParams.end = this.endSecondsValue
      providerParams.end_time = this.endSecondsValue
    }

    return {
      ...providerOptions,
      options: {
        providerParams,
        poster: this.posterValue,
        controls
      },
      onReady: this.handlePlayerReady.bind(this)
    }
  }

  // callbacks

  appear () {
    if (!this.ready) return
    this.#togglePictureInPicturePlayer(false)
  }

  disappear () {
    if (!this.ready) return
    this.#togglePictureInPicturePlayer(true)
  }

  handlePlayerReady (player) {
    this.ready = true
    // for seekTo to work we need to store again the player instance
    this.player = player

    const controlBar = player.elements.container.querySelector('.v-controlBar')

    if (controlBar) {
      const volumeButton = player.elements.container.querySelector('.v-volumeButton')
      const playbackRateSelect = this.createPlaybackRateSelect(this.playbackRateOptions, player)
      volumeButton.parentNode.insertBefore(playbackRateSelect, volumeButton.nextSibling)
    }

    if (this.providerValue === 'youtube') {
      // The overlay is messing with the hover state of he player
      player.elements.container.querySelector('.v-overlay').remove()

      // Setup YouTube API event listeners for logging
      this.setupYouTubeEventLogging(player)
    }
  }

  setupYouTubeEventLogging (player) {
    if (!player.instance) {
      console.log('YouTube API not available for event logging')
      return
    }

    const ytPlayer = player.instance

    ytPlayer.addEventListener('onStateChange', (event) => {
      const stateNames = {
        '-1': 'unstarted',
        0: 'ended',
        1: 'playing',
        2: 'paused',
        3: 'buffering',
        5: 'video cued'
      }

      console.log('YouTube Event: onStateChange', {
        event: 'onStateChange',
        state: event.data,
        stateName: stateNames[event.data] || 'unknown',
        currentTime: ytPlayer.getCurrentTime?.(),
        duration: ytPlayer.getDuration?.(),
        videoLoadedFraction: ytPlayer.getVideoLoadedFraction?.()
      })

      if (event.data === 1 && this.currentUserPresentValue) {
        this.startProgressTracking()
      } else if (event.data === 2 || event.data === 0) {
        this.stopProgressTracking()
      }
    })
  }

  startProgressTracking () {
    if (this.progressInterval) return
    if (!this.currentUserPresentValue) return

    this.progressInterval = setInterval(() => {
      if (this.player?.instance?.getCurrentTime && this.hasWatchedTalkPathValue) {
        const currentTime = this.player.instance.getCurrentTime()

        this.updateWatchedProgress(Math.floor(currentTime))
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
    if (!this.hasWatchedTalkPathValue) return
    if (!this.currentUserPresentValue) return

    patch(this.watchedTalkPathValue, {
      body: {
        watched_talk: {
          progress_seconds: progressSeconds
        }
      }
    }).catch(error => {
      console.error('Error updating watch progress:', error)
    })
  }

  createPlaybackRateSelect (options, player) {
    const playbackRateSelect = document.createElement('select')
    playbackRateSelect.className = 'v-playbackRateSelect v-controlButton'
    options.forEach(rate => {
      const option = document.createElement('option')
      option.value = rate
      option.textContent = rate + 'x'
      playbackRateSelect.appendChild(option)
    })

    playbackRateSelect.addEventListener('change', () => {
      player.instance.setPlaybackRate(parseFloat(playbackRateSelect.value))
    })

    return playbackRateSelect
  }

  seekTo (event) {
    if (!this.ready) return

    const { time } = event.params

    if (time) {
      this.player.seekTo(time)
    }
  }

  pause () {
    if (!this.ready) return

    this.player.pause()
  }

  disconnect () {
    this.stopProgressTracking()
  }

  #togglePictureInPicturePlayer (enabled) {
    const toggleClasses = () => {
      if (enabled && this.isPlaying) {
        this.playerWrapperTarget.classList.add('picture-in-picture')
        this.playerWrapperTarget.querySelector('.v-controlBar').classList.add('v-hidden')
      } else {
        this.playerWrapperTarget.classList.remove('picture-in-picture')
        this.playerWrapperTarget.querySelector('.v-controlBar').classList.remove('v-hidden')
      }
    }

    // Check if View Transition API is supported
    if (document.startViewTransition && typeof document.startViewTransition === 'function') {
      document.startViewTransition(toggleClasses)
    } else {
      // Fallback for browsers without View Transition API support
      toggleClasses()
    }
  }

  get isPlaying () {
    // Vlitejs doesn't have a method to check if the video is playing
    // there is a method to check if the video is paused
    if (this.player.isPaused === undefined || this.player.isPaused === null) {
      return false
    }

    return !this.player.isPaused
  }

  get isPreview () {
    return document.documentElement.hasAttribute('data-turbo-preview')
  }
}
