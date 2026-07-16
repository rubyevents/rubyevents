import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['tab', 'panel', 'cue', 'liveDot', 'liveLabel']

  connect () {
    this.live = true
    this.currentCue = null
    this.#openTabIfDeepLinked()
  }

  #openTabIfDeepLinked () {
    const params = new URLSearchParams(window.location.search)
    if (!params.has('t')) return

    const tab = this.element.closest('[role="tabpanel"]')?.previousElementSibling

    if (tab?.matches('input[type="radio"][role="tab"]')) {
      tab.checked = true
    }

    const time = Number(params.get('t'))
    if (Number.isNaN(time)) return

    requestAnimationFrame(() => requestAnimationFrame(() => {
      this.#activateCue(this.#cueAt(time), true)
    }))
  }

  selectLanguage (event) {
    const language = event.currentTarget.dataset.language

    this.tabTargets.forEach((tab) => {
      tab.classList.toggle('btn-primary', tab.dataset.language === language)
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.language !== language
    })

    this.clearHighlight()
  }

  seek (event) {
    const time = Number(event.currentTarget.dataset.start)
    if (Number.isNaN(time)) return

    this.dispatch('seek', { target: window, detail: { time } })
  }

  toggleLive (event) {
    this.live = !this.live

    const button = event.currentTarget
    button.classList.toggle('btn-primary', this.live)
    button.classList.toggle('btn-ghost', !this.live)
    button.setAttribute('aria-pressed', String(this.live))

    if (this.hasLiveDotTarget) {
      this.liveDotTarget.classList.toggle('bg-white', this.live)
      this.liveDotTarget.classList.toggle('bg-primary', !this.live)
      this.liveDotTarget.classList.toggle('animate-pulse', this.live)
    }

    if (this.hasLiveLabelTarget) this.liveLabelTarget.textContent = this.live ? 'Auto-Scroll' : 'Not scrolling'

    if (this.live && this.currentCue) this.scrollToCue(this.currentCue)
  }

  timeUpdate (event) {
    const time = event.detail.time
    if (time == null) return

    this.#activateCue(this.#cueAt(time))
  }

  #cueAt (time) {
    let current = null

    for (const cue of this.visibleCues()) {
      if (Number(cue.dataset.start) <= time) current = cue
      else break
    }

    return current
  }

  #activateCue (cue, forceScroll = false) {
    if (cue === this.currentCue) return

    this.clearHighlight()
    this.currentCue = cue

    if (cue) {
      cue.classList.add('bg-base-300', 'font-bold')
      if (this.live || forceScroll) this.scrollToCue(cue)
    }
  }

  clearHighlight () {
    if (!this.currentCue) return

    this.currentCue.classList.remove('bg-base-300', 'font-bold')
    this.currentCue = null
  }

  visibleCues () {
    return this.cueTargets.filter((cue) => !cue.hidden && cue.offsetParent !== null)
  }

  scrollToCue (cue) {
    const container = cue.closest('[data-transcript-scroll]')
    if (!container) return

    const top = cue.offsetTop - container.clientHeight / 2 + cue.clientHeight / 2
    container.scrollTo({ top: Math.max(top, 0), behavior: 'smooth' })
  }
}
