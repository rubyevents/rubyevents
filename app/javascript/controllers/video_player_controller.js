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
    durationSeconds: Number,
    watchedTalkPath: String,
    currentUserPresent: { default: false, type: Boolean },
    progressSeconds: { default: 0, type: Number },
    watched: { default: false, type: Boolean }
  }

  static targets = [
    'player', 'playerWrapper', 'watchedOverlay', 'resumeOverlay', 'playOverlay',
    'customControls', 'progressBar', 'progressHandle', 'progressBuffer', 'progressContainer',
    'currentTime', 'totalTime', 'playPauseBtn', 'centerPlayBtn', 'muteBtn',
    'volumeSlider', 'speedBtn', 'fullscreenBtn', 'seekTooltip'
  ]

  playbackRateOptions = [1, 1.25, 1.5, 1.75, 2]
  currentPlaybackRateIndex = 0
  lastTapTime = 0
  lastTapSide = null
  isDragging = false
  dragPercent = 0

  initialize () {
    useIntersection(this, { element: this.playerWrapperTarget, threshold: 0.5, visibleAttribute: null })
  }

  connect () {
    this.init()
    this.setupDoubleTap()
    this.setupKeyboardShortcuts()
    this.setupSeekDrag()
    this.setupIdleDetection()
    this.setupFullscreenListener()
  }

  setupFullscreenListener () {
    this.handleFullscreenChange = this.handleFullscreenChange.bind(this)
    document.addEventListener('fullscreenchange', this.handleFullscreenChange)
    document.addEventListener('webkitfullscreenchange', this.handleFullscreenChange)
  }

  handleFullscreenChange () {
    const isFullscreen = document.fullscreenElement || document.webkitFullscreenElement
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element

    if (isFullscreen) {
      wrapper.classList.add('is-fullscreen')
      wrapper.classList.remove('rounded-xl', 'overflow-hidden')
    } else {
      wrapper.classList.remove('is-fullscreen')
      wrapper.classList.add('rounded-xl', 'overflow-hidden')
    }

    this.updateFullscreenButton(isFullscreen)
  }

  updateFullscreenButton (isFullscreen) {
    if (!this.hasFullscreenBtnTarget) return

    if (isFullscreen) {
      this.fullscreenBtnTarget.innerHTML = '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><path d="M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z"/></svg>'
      this.fullscreenBtnTarget.setAttribute('data-tooltip', 'Exit Fullscreen (F)')
    } else {
      this.fullscreenBtnTarget.innerHTML = '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>'
      this.fullscreenBtnTarget.setAttribute('data-tooltip', 'Fullscreen (F)')
    }
  }

  setupSeekDrag () {
    this.onDragMove = this.onDragMove.bind(this)
    this.onDragEnd = this.onDragEnd.bind(this)
  }

  setupIdleDetection () {
    this.idleTimeout = null
    this.idleDelay = 3000

    this.handleMouseMove = this.handleMouseMove.bind(this)
    this.handleMouseLeave = this.handleMouseLeave.bind(this)

    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    wrapper.addEventListener('mousemove', this.handleMouseMove)
    wrapper.addEventListener('mouseleave', this.handleMouseLeave)
  }

  handleMouseMove () {
    this.showControls()
    this.resetIdleTimer()
  }

  handleMouseLeave () {
    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
      this.idleTimeout = null
    }
    if (this.isPlaying) {
      this.hideControls()
    }
  }

  resetIdleTimer () {
    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
    }

    if (this.isPlaying) {
      this.idleTimeout = setTimeout(() => {
        this.hideControls()
      }, this.idleDelay)
    }
  }

  showControls () {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    wrapper.classList.add('show-controls')
    wrapper.classList.remove('hide-cursor')
  }

  hideControls () {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    wrapper.classList.remove('show-controls')
    wrapper.classList.add('hide-cursor')
  }

  setupKeyboardShortcuts () {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.handleKeydown)
  }

  handleKeydown (event) {
    if (!this.ready) return
    if (this.isTyping(event)) return

    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    if (!wrapper.classList.contains('video-started')) return

    switch (event.key) {
      case ' ':
      case 'k':
        event.preventDefault()
        this.togglePlay()
        break
      case 'ArrowLeft':
      case 'j':
        event.preventDefault()
        this.skipBy(event.key === 'j' ? -10 : -5)
        break
      case 'ArrowRight':
      case 'l':
        event.preventDefault()
        this.skipBy(event.key === 'l' ? 10 : 5)
        break
      case 'f':
        event.preventDefault()
        this.toggleFullscreen()
        break
      case 'm':
        event.preventDefault()
        this.toggleMute()
        break
      case 'p':
        event.preventDefault()
        this.togglePictureInPicture()
        break
    }
  }

  isTyping (event) {
    const target = event.target
    return target.tagName === 'INPUT' ||
           target.tagName === 'TEXTAREA' ||
           target.tagName === 'SELECT' ||
           target.isContentEditable
  }

  setupDoubleTap () {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    wrapper.addEventListener('click', this.handleDoubleTap.bind(this))
  }

  handleDoubleTap (event) {
    if (!this.ready) return
    if (event.target.closest('.custom-player-controls, .custom-player-bottom, button, input')) return

    const now = Date.now()
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    const rect = wrapper.getBoundingClientRect()
    const clickX = event.clientX - rect.left
    const side = clickX < rect.width / 2 ? 'left' : 'right'

    if (now - this.lastTapTime < 300 && side === this.lastTapSide) {
      if (side === 'left') {
        this.skipBy(-5)
        this.showSkipIndicator('left', '-5s')
      } else {
        this.skipBy(5)
        this.showSkipIndicator('right', '+5s')
      }
      this.lastTapTime = 0
      this.lastTapSide = null
    } else {
      this.lastTapTime = now
      this.lastTapSide = side
    }
  }

  showSkipIndicator (side, text) {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
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
    wrapper.appendChild(indicator)

    setTimeout(() => indicator.remove(), 500)
  }

  init () {
    if (this.isPreview) return
    if (!this.hasPlayerTarget) return
    if (this.watchedValue) return
    if (this.hasResumeOverlayTarget || this.hasPlayOverlayTarget) return

    this.player = new Vlitejs(this.playerTarget, this.options)
  }

  dismissWatchedOverlay (event) {
    // Don't start playback if clicking on a link, button, or form
    if (event?.target?.closest('a, button, form')) return

    this.showLoadingState(this.watchedOverlayTarget)
    this.watchedValue = false
    this.autoplay = true
    this.player = new Vlitejs(this.playerTarget, this.options)
  }

  resumePlayback (event) {
    // Don't start playback if clicking on a link, button, or form
    if (event?.target?.closest('a, button, form')) return

    this.showLoadingState(this.resumeOverlayTarget)
    this.autoplay = true
    this.player = new Vlitejs(this.playerTarget, this.options)
  }

  startPlayback (event) {
    // Don't start playback if clicking on a link, button, or form
    if (event?.target?.closest('a, button, form')) return

    this.showLoadingState(this.playOverlayTarget)
    this.autoplay = true
    this.player = new Vlitejs(this.playerTarget, this.options)
  }

  showLoadingState (overlay) {
    if (!overlay) return

    // Add loading class
    overlay.classList.add('loading')

    // Hide/fade out elements that create darkness
    const gradients = overlay.querySelectorAll('[class*="bg-gradient"]')
    gradients.forEach(g => (g.style.opacity = '0'))

    const actionButtons = overlay.querySelector('.player-action-buttons')
    if (actionButtons) actionButtons.style.opacity = '0'

    // Fade out the thumbnail image
    const image = overlay.querySelector(':scope > img')
    if (image) image.style.opacity = '0'

    // Find the center content area (the one with justify-center) and replace with spinner
    const centerContent = overlay.querySelector('.justify-center')
    if (centerContent) {
      centerContent.innerHTML = `
        <div class="p-4 bg-white/20 backdrop-blur-sm rounded-full">
          <svg class="animate-spin h-8 w-8 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </div>
        <div class="text-sm text-white/80">Loading...</div>
      `
    }
  }

  removeOverlays () {
    if (this.hasWatchedOverlayTarget) this.watchedOverlayTarget.remove()
    if (this.hasResumeOverlayTarget) this.resumeOverlayTarget.remove()
    if (this.hasPlayOverlayTarget) this.playOverlayTarget.remove()

    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    wrapper.classList.add('video-started')

    if (this.providerValue === 'youtube') {
      wrapper.classList.add('show-controls')
      setTimeout(() => {
        wrapper.classList.remove('show-controls')
      }, 3000)
    }
  }

  get options () {
    const providerOptions = {}
    const providerParams = {}
    const controls = false

    if (this.hasProviderValue && this.providerValue === 'youtube') {
      providerOptions.controls = 0
      providerOptions.disablekb = 1
      providerOptions.fs = 0
      providerOptions.iv_load_policy = 3
      providerOptions.rel = 0
      providerOptions.modestbranding = 1
      providerOptions.playsinline = 1
      providerOptions.showinfo = 0
      providerOptions.cc_load_policy = 0
      providerOptions.autohide = 1
      providerOptions.origin = window.location.origin
      providerParams.mute = 0
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
    this.player = player

    const controlBar = player.elements.container.querySelector('.v-controlBar')

    if (controlBar) {
      const volumeButton = player.elements.container.querySelector('.v-volumeButton')
      const playbackRateSelect = this.createPlaybackRateSelect(this.playbackRateOptions, player)
      volumeButton.parentNode.insertBefore(playbackRateSelect, volumeButton.nextSibling)
    }

    if (this.providerValue === 'youtube') {
      player.elements.container.querySelector('.v-overlay').remove()
      this.setupYouTubeEventLogging(player)
    }

    if (this.providerValue === 'vimeo') {
      player.instance.on('ended', () => {
        this.setPlayingState(false)
        this.stopUIUpdateLoop()
        this.handleVideoEnded()
      })

      player.instance.on('pause', () => {
        this.setPlayingState(false)
        this.stopUIUpdateLoop()
        this.handleVideoPaused()
      })

      player.instance.on('play', () => {
        this.setPlayingState(true)
        this.startUIUpdateLoop()
        this.startProgressTracking()
      })
    }

    if (this.providerValue === 'mp4' && player.media) {
      player.media.addEventListener('play', () => {
        this.setPlayingState(true)
        this.startUIUpdateLoop()
        this.startProgressTracking()
      })

      player.media.addEventListener('pause', () => {
        this.setPlayingState(false)
        this.stopUIUpdateLoop()
        this.handleVideoPaused()
      })

      player.media.addEventListener('ended', () => {
        this.setPlayingState(false)
        this.stopUIUpdateLoop()
        this.handleVideoEnded()
      })

      player.media.addEventListener('loadedmetadata', () => {
        this.updateDurationDisplay(player.media.duration)
      })

      if (player.media.duration && !isNaN(player.media.duration)) {
        this.updateDurationDisplay(player.media.duration)
      }
    } else {
      this.fetchExternalPlayerDuration()
    }

    if (this.hasProgressSecondsValue && this.progressSecondsValue > 0 && !this.isFullyWatched()) {
      this.player.seekTo(this.progressSecondsValue)
    }

    if (this.autoplay) {
      this.autoplay = false
      this.player.play()

      if (this.player.unMute) {
        this.player.unMute()
      }

      this.removeOverlays()
    }
  }

  setupYouTubeEventLogging (player) {
    if (!player.instance) {
      console.log('YouTube API not available for event logging')
      return
    }

    const ytPlayer = player.instance

    ytPlayer.addEventListener('onStateChange', (event) => {
      const YOUTUBE_STATES = {
        ENDED: 0,
        PLAYING: 1,
        PAUSED: 2
      }

      if (event.data === YOUTUBE_STATES.PLAYING) {
        this.setPlayingState(true)
        this.startUIUpdateLoop()
        if (this.currentUserPresentValue) {
          this.startProgressTracking()
        }
      } else if (event.data === YOUTUBE_STATES.PAUSED) {
        this.setPlayingState(false)
        this.stopUIUpdateLoop()
        this.handleVideoPaused()
      } else if (event.data === YOUTUBE_STATES.ENDED) {
        this.setPlayingState(false)
        this.stopUIUpdateLoop()
        this.handleVideoEnded()
      }
    })
  }

  async startProgressTracking () {
    if (this.progressInterval) return
    if (!this.currentUserPresentValue) return

    const currentTime = await this.getCurrentTime()
    this.progressSecondsValue = Math.floor(currentTime)

    this.updateWatchedProgress(this.progressSecondsValue)

    this.progressInterval = setInterval(async () => {
      if (this.hasWatchedTalkPathValue) {
        const currentTime = await this.getCurrentTime()
        this.progressSecondsValue = Math.floor(currentTime)

        this.updateWatchedProgress(this.progressSecondsValue)
      }
    }, 5000)
  }

  stopProgressTracking () {
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
      this.progressInterval = null
    }
  }

  async handleVideoPaused () {
    this.stopProgressTracking()

    const currentTime = await this.getCurrentTime()
    this.progressSecondsValue = Math.floor(currentTime)
    this.updateWatchedProgress(this.progressSecondsValue)
  }

  async handleVideoEnded () {
    this.stopProgressTracking()

    if (this.hasDurationSecondsValue && this.durationSecondsValue > 0) {
      this.progressSecondsValue = this.durationSecondsValue
      this.updateWatchedProgress(this.durationSecondsValue)
    }
  }

  isFullyWatched () {
    if (!this.hasDurationSecondsValue || this.durationSecondsValue <= 0) return false

    return this.progressSecondsValue >= this.durationSecondsValue - 5
  }

  updateWatchedProgress (progressSeconds) {
    if (!this.hasWatchedTalkPathValue) return
    if (!this.currentUserPresentValue) return

    patch(this.watchedTalkPathValue, {
      body: {
        watched_talk: {
          progress_seconds: progressSeconds
        }
      },
      responseKind: 'turbo-stream'
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

  async openOnExternalPlayer (event) {
    event.preventDefault()

    const baseUrl = event.currentTarget.dataset.externalUrl
    if (!baseUrl) return

    const currentTime = await this.getCurrentTime()
    const seconds = Math.floor(currentTime)

    let url = baseUrl
    if (baseUrl.includes('youtube.com') || baseUrl.includes('youtu.be')) {
      const separator = baseUrl.includes('?') ? '&' : '?'
      url = `${baseUrl}${separator}t=${seconds}`
    } else if (baseUrl.includes('vimeo.com')) {
      url = `${baseUrl}#t=${seconds}s`
    }

    this.pause()
    window.open(url, '_blank')
  }

  disconnect () {
    this.stopProgressTracking()
    this.stopUIUpdateLoop()
    document.removeEventListener('keydown', this.handleKeydown)
    document.removeEventListener('fullscreenchange', this.handleFullscreenChange)
    document.removeEventListener('webkitfullscreenchange', this.handleFullscreenChange)

    if (this.idleTimeout) {
      clearTimeout(this.idleTimeout)
    }
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    wrapper.removeEventListener('mousemove', this.handleMouseMove)
    wrapper.removeEventListener('mouseleave', this.handleMouseLeave)
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

    if (document.startViewTransition && typeof document.startViewTransition === 'function') {
      document.startViewTransition(toggleClasses)
    } else {
      toggleClasses()
    }
  }

  get isPlaying () {
    if (this.player.isPaused === undefined || this.player.isPaused === null) {
      return false
    }

    return !this.player.isPaused
  }

  get isPreview () {
    return document.documentElement.hasAttribute('data-turbo-preview')
  }

  async getCurrentTime () {
    try {
      if (this.providerValue === 'mp4' && this.player.media) {
        return this.player.media.currentTime
      }
      return await this.player.instance.getCurrentTime()
    } catch (error) {
      console.error('Error getting current time:', error)
      return 0
    }
  }

  togglePlay () {
    if (!this.ready) return

    if (this.isPlaying) {
      this.player.pause()
      this.setPlayingState(false)
    } else {
      this.player.play()
      this.setPlayingState(true)
    }
  }

  setPlayingState (playing) {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    wrapper.classList.toggle('playing', playing)
    wrapper.classList.toggle('paused', !playing)

    if (playing && !wrapper.classList.contains('video-started')) {
      wrapper.classList.add('video-started')
    }

    if (this.hasPlayPauseBtnTarget) {
      this.playPauseBtnTarget.innerHTML = playing
        ? '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>'
        : '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>'
    }

    if (this.hasCenterPlayBtnTarget) {
      this.centerPlayBtnTarget.innerHTML = playing
        ? '<svg class="fill-white w-10 h-10" viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>'
        : '<svg class="fill-white w-10 h-10 ml-1" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>'
    }
  }

  skipForward () {
    if (!this.ready) return
    this.skipBy(10)
  }

  skipBackward () {
    if (!this.ready) return
    this.skipBy(-10)
  }

  async skipBy (seconds) {
    const currentTime = await this.getCurrentTime()
    const newTime = Math.max(0, currentTime + seconds)

    if (this.providerValue === 'mp4' && this.player.media) {
      this.player.media.currentTime = newTime
    } else {
      this.player.seekTo(newTime)
    }
  }

  toggleMute () {
    if (!this.ready) return

    if (this.providerValue === 'mp4' && this.player.media) {
      this.player.media.muted = !this.player.media.muted
      this.isMuted = this.player.media.muted
    } else if (this.player.instance) {
      if (this.isMuted) {
        this.player.unMute?.() || this.player.instance.unMute?.()
        this.isMuted = false
      } else {
        this.player.mute?.() || this.player.instance.mute?.()
        this.isMuted = true
      }
    }

    this.updateMuteButton()
  }

  updateMuteButton () {
    if (!this.hasMuteBtnTarget) return

    this.muteBtnTarget.innerHTML = this.isMuted
      ? '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>'
      : '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>'
  }

  setVolume (event) {
    if (!this.ready || !this.player.instance) return

    const volume = event.target.value / 100

    if (this.player.instance.setVolume) {
      this.player.instance.setVolume(volume)
    }

    this.isMuted = volume === 0
    this.updateMuteButton()
  }

  adjustVolume (delta) {
    if (!this.ready || !this.player.instance) return

    const currentVolume = this.hasVolumeSliderTarget ? parseInt(this.volumeSliderTarget.value) : 100
    const newVolume = Math.max(0, Math.min(100, currentVolume + delta))

    if (this.player.instance.setVolume) {
      this.player.instance.setVolume(newVolume / 100)
    }

    if (this.hasVolumeSliderTarget) {
      this.volumeSliderTarget.value = newVolume
    }

    this.isMuted = newVolume === 0
    this.updateMuteButton()
  }

  cyclePlaybackRate () {
    if (!this.ready) return

    this.currentPlaybackRateIndex = (this.currentPlaybackRateIndex + 1) % this.playbackRateOptions.length
    const rate = this.playbackRateOptions[this.currentPlaybackRateIndex]

    if (this.providerValue === 'mp4' && this.player.media) {
      this.player.media.playbackRate = rate
    } else if (this.player.instance?.setPlaybackRate) {
      this.player.instance.setPlaybackRate(rate)
    }

    if (this.hasSpeedBtnTarget) {
      this.speedBtnTarget.textContent = `${rate}x`
    }
  }

  startDrag (event) {
    if (!this.ready) return

    event.preventDefault()
    this.isDragging = true
    this.dragProgressContainer = event.currentTarget
    this.dragProgressContainer.classList.add('dragging')

    document.addEventListener('mousemove', this.onDragMove)
    document.addEventListener('mouseup', this.onDragEnd)
    document.addEventListener('touchmove', this.onDragMove)
    document.addEventListener('touchend', this.onDragEnd)

    this.onDragMove(event)

    if (this.hasSeekTooltipTarget) {
      this.seekTooltipTarget.classList.add('visible')
    }
  }

  onDragMove (event) {
    if (!this.isDragging || !this.dragProgressContainer) return

    const clientX = event.touches ? event.touches[0].clientX : event.clientX
    const rect = this.dragProgressContainer.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
    this.dragPercent = percent

    const duration = this.durationSecondsValue || 0
    const seekTime = percent * duration

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percent * 100}%`
    }
    if (this.hasProgressHandleTarget) {
      this.progressHandleTarget.style.left = `${percent * 100}%`
    }

    if (this.hasSeekTooltipTarget) {
      this.seekTooltipTarget.textContent = this.formatTime(seekTime)
      this.seekTooltipTarget.style.left = `${percent * 100}%`
    }
  }

  async onDragEnd (event) {
    if (!this.isDragging) return

    document.removeEventListener('mousemove', this.onDragMove)
    document.removeEventListener('mouseup', this.onDragEnd)
    document.removeEventListener('touchmove', this.onDragMove)
    document.removeEventListener('touchend', this.onDragEnd)

    if (this.hasSeekTooltipTarget) {
      this.seekTooltipTarget.classList.remove('visible')
    }
    if (this.dragProgressContainer) {
      this.dragProgressContainer.classList.remove('dragging')
    }

    const duration = this.durationSecondsValue || await this.getDuration()
    const seekTime = this.dragPercent * duration

    if (this.providerValue === 'mp4' && this.player.media) {
      this.player.media.currentTime = seekTime
    } else {
      this.player.seekTo(seekTime)
    }

    this.progressSecondsValue = Math.floor(seekTime)
    this.updateWatchedProgress(this.progressSecondsValue)

    this.isDragging = false
    this.dragProgressContainer = null
  }

  async seekToPosition (event) {
    if (!this.ready) return

    const progressContainer = event.currentTarget
    const rect = progressContainer.getBoundingClientRect()
    const percent = (event.clientX - rect.left) / rect.width
    const duration = this.durationSecondsValue || await this.getDuration()
    const seekTime = percent * duration

    if (this.providerValue === 'mp4' && this.player.media) {
      this.player.media.currentTime = seekTime
    } else {
      this.player.seekTo(seekTime)
    }

    this.progressSecondsValue = Math.floor(seekTime)
    this.updateWatchedProgress(this.progressSecondsValue)
  }

  showSeekPreview (event) {
    if (this.isDragging || !this.hasSeekTooltipTarget) return

    const progressContainer = event.currentTarget
    const rect = progressContainer.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    const duration = this.durationSecondsValue || 0
    const seekTime = percent * duration

    this.seekTooltipTarget.textContent = this.formatTime(seekTime)
    this.seekTooltipTarget.style.left = `${percent * 100}%`
    this.seekTooltipTarget.classList.add('visible')
  }

  hideSeekPreview () {
    if (this.isDragging || !this.hasSeekTooltipTarget) return
    this.seekTooltipTarget.classList.remove('visible')
  }

  async getDuration () {
    try {
      if (this.providerValue === 'mp4' && this.player.media) {
        return this.player.media.duration || this.durationSecondsValue || 0
      }
      if (this.player.instance.getDuration) {
        return await this.player.instance.getDuration()
      }
    } catch (e) {}
    return this.durationSecondsValue || 0
  }

  toggleFullscreen () {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    const isFullscreen = document.fullscreenElement || document.webkitFullscreenElement

    if (isFullscreen) {
      if (document.exitFullscreen) {
        document.exitFullscreen()
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen()
      }
    } else {
      if (wrapper.requestFullscreen) {
        wrapper.requestFullscreen()
      } else if (wrapper.webkitRequestFullscreen) {
        wrapper.webkitRequestFullscreen()
      }
    }
  }

  async togglePictureInPicture () {
    if (this.providerValue !== 'mp4' || !this.player?.media) return

    try {
      if (document.pictureInPictureElement) {
        await document.exitPictureInPicture()
      } else if (document.pictureInPictureEnabled) {
        await this.player.media.requestPictureInPicture()
      }
    } catch (error) {
      console.error('Picture-in-Picture error:', error)
    }
  }

  get supportsPictureInPicture () {
    return this.providerValue === 'mp4' && document.pictureInPictureEnabled
  }

  async updateProgressUI () {
    if (!this.ready) return

    const currentTime = await this.getCurrentTime()
    const duration = this.durationSecondsValue || await this.getDuration()

    if (duration <= 0) return

    const percent = (currentTime / duration) * 100

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percent}%`
    }

    if (this.hasProgressHandleTarget) {
      this.progressHandleTarget.style.left = `${percent}%`
    }

    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = this.formatTime(currentTime)
    }

    this.dispatch('progressUpdate', {
      detail: { currentTime, duration, percent }
    })
  }

  formatTime (seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  updateDurationDisplay (duration) {
    if (!duration || isNaN(duration)) return

    this.durationSecondsValue = duration

    if (this.hasTotalTimeTarget) {
      this.totalTimeTarget.textContent = this.formatTime(duration)
    }
  }

  async fetchExternalPlayerDuration () {
    await new Promise(resolve => setTimeout(resolve, 500))

    try {
      if (this.player?.instance?.getDuration) {
        const duration = await this.player.instance.getDuration()
        if (duration && duration > 0) {
          this.updateDurationDisplay(duration)
        }
      }
    } catch (e) {}
  }

  startUIUpdateLoop () {
    if (this.uiUpdateInterval) return

    this.uiUpdateInterval = setInterval(() => {
      this.updateProgressUI()
    }, 250)
  }

  stopUIUpdateLoop () {
    if (this.uiUpdateInterval) {
      clearInterval(this.uiUpdateInterval)
      this.uiUpdateInterval = null
    }
  }
}
