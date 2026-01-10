import { Controller } from '@hotwired/stimulus'
import { useIntersection } from 'stimulus-use'

import { Player } from '~/lib/player/player'
import { IdleDetector } from '~/lib/player/idle_detector'
import { KeyboardShortcuts } from '~/lib/player/keyboard_shortcuts'
import { DoubleTapHandler } from '~/lib/player/double_tap_handler'
import { SeekDragHandler } from '~/lib/player/seek_drag_handler'

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

  initialize () {
    useIntersection(this, { element: this.playerWrapperTarget, threshold: 0.5, visibleAttribute: null })
  }

  connect () {
    this.init()
    this.setupHelpers()
    this.setupFullscreenListener()
  }

  disconnect () {
    this.videoPlayer?.destroy()
    this.idleDetector?.stop()
    this.keyboardShortcuts?.stop()
    this.doubleTapHandler?.stop()
    document.removeEventListener('fullscreenchange', this.handleFullscreenChange)
    document.removeEventListener('webkitfullscreenchange', this.handleFullscreenChange)
  }

  init () {
    if (this.isPreview) return
    if (!this.hasPlayerTarget) return
    if (this.watchedValue) return
    if (this.hasResumeOverlayTarget || this.hasPlayOverlayTarget) return

    this.createPlayer()
  }

  createPlayer () {
    this.videoPlayer = new Player({
      element: this.playerTarget,
      provider: this.hasProviderValue ? this.providerValue : null,
      poster: this.posterValue,
      startSeconds: this.hasStartSecondsValue ? this.startSecondsValue : null,
      endSeconds: this.hasEndSecondsValue ? this.endSecondsValue : null,
      durationSeconds: this.durationSecondsValue,
      progressSeconds: this.progressSecondsValue,
      watchedTalkPath: this.hasWatchedTalkPathValue ? this.watchedTalkPathValue : null,
      currentUserPresent: this.currentUserPresentValue,
      onReady: () => this.handlePlayerReady(),
      onPlay: () => this.updatePlayingUI(true),
      onPause: () => this.updatePlayingUI(false),
      onEnded: () => this.updatePlayingUI(false),
      onTimeUpdate: (current, duration, percent) => this.updateProgressUI(current, duration, percent),
      onDurationChange: (duration) => this.updateDurationDisplay(duration)
    })

    this.videoPlayer.init()
  }

  handlePlayerReady () {
    if (this.autoplay) {
      this.autoplay = false
      this.videoPlayer.play()
      this.removeOverlays()
    }
  }

  setupHelpers () {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element

    this.idleDetector = new IdleDetector({
      element: wrapper,
      idleDelay: 3000,
      onIdle: () => this.hideControls(),
      onActive: () => this.showControls(),
      checkPlaying: () => this.videoPlayer?.playing
    })
    this.idleDetector.start()

    this.keyboardShortcuts = new KeyboardShortcuts({
      bindings: {
        ' ': () => this.togglePlay(),
        k: () => this.togglePlay(),
        ArrowLeft: () => this.videoPlayer?.skipBackward(5),
        j: () => this.videoPlayer?.skipBackward(10),
        ArrowRight: () => this.videoPlayer?.skipForward(5),
        l: () => this.videoPlayer?.skipForward(10),
        f: () => this.toggleFullscreen(),
        m: () => this.toggleMute(),
        p: () => this.togglePictureInPicture()
      },
      enabledCheck: () => this.videoPlayer?.ready && this.isVideoStarted
    })
    this.keyboardShortcuts.start()

    this.doubleTapHandler = new DoubleTapHandler({
      element: wrapper,
      skipAmount: 5,
      onDoubleTapLeft: () => this.videoPlayer?.skipBackward(5),
      onDoubleTapRight: () => this.videoPlayer?.skipForward(5),
      enabledCheck: () => this.videoPlayer?.ready
    })
    this.doubleTapHandler.start()

    if (this.hasProgressContainerTarget) {
      this.seekDragHandler = new SeekDragHandler({
        progressContainer: this.progressContainerTarget,
        progressBar: this.hasProgressBarTarget ? this.progressBarTarget : null,
        progressHandle: this.hasProgressHandleTarget ? this.progressHandleTarget : null,
        seekTooltip: this.hasSeekTooltipTarget ? this.seekTooltipTarget : null,
        getDuration: () => this.videoPlayer?.durationSeconds || 0,
        onSeek: (time) => this.videoPlayer?.seekTo(time),
        formatTime: (seconds) => this.videoPlayer?.formatTime(seconds) || '0:00'
      })
    }
  }

  setupFullscreenListener () {
    this.handleFullscreenChange = this.handleFullscreenChange.bind(this)
    document.addEventListener('fullscreenchange', this.handleFullscreenChange)
    document.addEventListener('webkitfullscreenchange', this.handleFullscreenChange)
  }

  // Overlay Management

  dismissWatchedOverlay (event) {
    if (event?.target?.closest('a, button, form')) return

    this.showLoadingState(this.watchedOverlayTarget)
    this.watchedValue = false
    this.autoplay = true
    this.createPlayer()
  }

  resumePlayback (event) {
    if (event?.target?.closest('a, button, form')) return

    this.showLoadingState(this.resumeOverlayTarget)
    this.autoplay = true
    this.createPlayer()
  }

  startPlayback (event) {
    if (event?.target?.closest('a, button, form')) return

    this.showLoadingState(this.playOverlayTarget)
    this.autoplay = true
    this.createPlayer()
  }

  showLoadingState (overlay) {
    if (!overlay) return

    overlay.classList.add('loading')

    overlay.querySelectorAll('[class*="bg-gradient"]').forEach(g => (g.style.opacity = '0'))

    const actionButtons = overlay.querySelector('.player-action-buttons')
    if (actionButtons) actionButtons.style.opacity = '0'

    const image = overlay.querySelector(':scope > img')
    if (image) image.style.opacity = '0'

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
      setTimeout(() => wrapper.classList.remove('show-controls'), 3000)
    }
  }

  // UI Updates

  updatePlayingUI (playing) {
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

  updateProgressUI (currentTime, duration, percent) {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percent}%`
    }

    if (this.hasProgressHandleTarget) {
      this.progressHandleTarget.style.left = `${percent}%`
    }

    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = this.videoPlayer.formatTime(currentTime)
    }

    this.dispatch('progressUpdate', { detail: { currentTime, duration, percent } })
  }

  updateDurationDisplay (duration) {
    this.durationSecondsValue = duration

    if (this.hasTotalTimeTarget) {
      this.totalTimeTarget.textContent = this.videoPlayer.formatTime(duration)
    }
  }

  updateMuteButton () {
    if (!this.hasMuteBtnTarget) return

    this.muteBtnTarget.innerHTML = this.videoPlayer?.muted
      ? '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>'
      : '<svg class="fill-white w-5 h-5" viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>'
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

  // Player Actions (delegated to Player)

  togglePlay () {
    this.videoPlayer?.togglePlay()
  }

  pause () {
    this.videoPlayer?.pause()
  }

  seekTo (event) {
    if (!this.videoPlayer?.ready) return

    const time = event?.params?.time
    if (time !== undefined) {
      this.videoPlayer.seekTo(time)
    }
  }

  skipForward () {
    this.videoPlayer?.skipForward(10)
  }

  skipBackward () {
    this.videoPlayer?.skipBackward(10)
  }

  toggleMute () {
    this.videoPlayer?.toggleMute()
    this.updateMuteButton()
  }

  setVolume (event) {
    const volume = event.target.value / 100
    this.videoPlayer?.setVolume(volume)
    this.updateMuteButton()
  }

  cyclePlaybackRate () {
    const rate = this.videoPlayer?.cyclePlaybackRate()
    if (this.hasSpeedBtnTarget && rate) {
      this.speedBtnTarget.textContent = `${rate}x`
    }
  }

  // Seek Drag Handler delegation

  startDrag (event) {
    this.seekDragHandler?.startDrag(event)
  }

  showSeekPreview (event) {
    this.seekDragHandler?.showSeekPreview(event)
  }

  hideSeekPreview () {
    this.seekDragHandler?.hideSeekPreview()
  }

  // Fullscreen

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

  // Picture in Picture

  async togglePictureInPicture () {
    if (this.providerValue !== 'mp4' || !this.videoPlayer?.vlitejs?.media) return

    try {
      if (document.pictureInPictureElement) {
        await document.exitPictureInPicture()
      } else if (document.pictureInPictureEnabled) {
        await this.videoPlayer.vlitejs.media.requestPictureInPicture()
      }
    } catch (error) {
      console.error('Picture-in-Picture error:', error)
    }
  }

  appear () {
    if (!this.videoPlayer?.ready) return
    this.#togglePictureInPicturePlayer(false)
  }

  disappear () {
    if (!this.videoPlayer?.ready) return
    this.#togglePictureInPicturePlayer(true)
  }

  #togglePictureInPicturePlayer (enabled) {
    const toggleClasses = () => {
      if (enabled && this.videoPlayer?.playing) {
        this.playerWrapperTarget.classList.add('picture-in-picture')
        this.playerWrapperTarget.querySelector('.v-controlBar')?.classList.add('v-hidden')
      } else {
        this.playerWrapperTarget.classList.remove('picture-in-picture')
        this.playerWrapperTarget.querySelector('.v-controlBar')?.classList.remove('v-hidden')
      }
    }

    if (document.startViewTransition && typeof document.startViewTransition === 'function') {
      document.startViewTransition(toggleClasses)
    } else {
      toggleClasses()
    }
  }

  // External Player

  async openOnExternalPlayer (event) {
    event.preventDefault()

    const baseUrl = event.currentTarget.dataset.externalUrl
    if (!baseUrl) return

    const currentTime = await this.videoPlayer?.getCurrentTime() || 0
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

  // Getters

  get isVideoStarted () {
    const wrapper = this.hasPlayerWrapperTarget ? this.playerWrapperTarget : this.element
    return wrapper.classList.contains('video-started')
  }

  get isPreview () {
    return document.documentElement.hasAttribute('data-turbo-preview')
  }
}
