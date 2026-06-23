import { Controller } from '@hotwired/stimulus'
import { post, destroy } from '@rails/request.js'

export default class extends Controller {
  static targets = ['solid', 'regular', 'message']

  static values = {
    bookmarked: Boolean,
    addUrl: String,
    removeUrl: String
  }

  toggle (event) {
    event.preventDefault()

    const wasBookmarked = this.bookmarkedValue
    this.#render(!wasBookmarked)
    this.#showMessage(wasBookmarked ? 'Removed from bookmarks' : 'Added to bookmarks')

    const url = wasBookmarked ? this.removeUrlValue : this.addUrlValue
    const request = wasBookmarked ? destroy(url) : post(url)

    request.catch(() => this.#render(wasBookmarked))
  }

  #render (bookmarked) {
    this.bookmarkedValue = bookmarked
    this.solidTarget.classList.toggle('hidden', !bookmarked)
    this.regularTarget.classList.toggle('hidden', bookmarked)
  }

  #showMessage (text) {
    if (!this.hasMessageTarget) return

    const message = this.messageTarget
    message.textContent = text
    message.classList.remove('hidden')

    requestAnimationFrame(() => message.classList.remove('opacity-0', '-translate-y-1'))

    clearTimeout(this.messageTimer)
    this.messageTimer = setTimeout(() => {
      message.classList.add('opacity-0', '-translate-y-1')
      message.addEventListener('transitionend', () => message.classList.add('hidden'), { once: true })
    }, 1600)
  }
}
