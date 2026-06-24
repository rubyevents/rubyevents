import { Controller } from '@hotwired/stimulus'

const MAX_CONCURRENT = 3
let active = 0
const waiters = []

function acquire () {
  return new Promise((resolve) => {
    if (active < MAX_CONCURRENT) {
      active += 1
      resolve()
    } else {
      waiters.push(resolve)
    }
  })
}

function release () {
  if (waiters.length > 0) {
    waiters.shift()()
  } else {
    active = Math.max(0, active - 1)
  }
}

export default class extends Controller {
  static targets = ['image', 'spinner', 'error']
  static values = { url: String }

  connect () {
    this.state = 'idle'

    this.regenerateAll = () => this.generate(true)
    window.addEventListener('thumbnails:regenerate-all', this.regenerateAll)

    this.observer = new window.IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          this.observer.disconnect()
          this.generate()
        }
      },
      { rootMargin: '300px' }
    )
    this.observer.observe(this.element)
  }

  disconnect () {
    this.observer?.disconnect()
    window.removeEventListener('thumbnails:regenerate-all', this.regenerateAll)
  }

  async generate (force = false) {
    if (this.state === 'loading') return
    if (this.state === 'done' && !force) return

    this.setState('loading')
    await acquire()

    const img = new window.Image()
    const finish = () => release()

    img.addEventListener('load', () => {
      this.imageTarget.src = img.src
      this.setState('done')
      finish()
    })
    img.addEventListener('error', () => {
      this.setState('error')
      finish()
    })

    const separator = this.urlValue.includes('?') ? '&' : '?'
    img.src = `${this.urlValue}${separator}t=${Date.now()}`
  }

  regenerate () {
    this.generate(true)
  }

  setState (state) {
    this.state = state
    this.element.dataset.state = state
    this.spinnerTarget.hidden = state !== 'loading'
    this.imageTarget.hidden = state !== 'done'
    if (this.hasErrorTarget) this.errorTarget.hidden = state !== 'error'
  }
}
