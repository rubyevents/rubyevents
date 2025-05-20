import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="top-banner"

const ONE_MONTH = 30 * 24 * 60 * 60 * 1000 // 30 days in milliseconds
const COOKIE_NAME = 'top_banner_dismissed'

export default class extends Controller {
  connect () {
    if (!this.isDismissed) {
      this.element.classList.remove('hidden')
    }
  }

  dismiss () {
    this.element.classList.add('hidden')
    this.#setCookie(COOKIE_NAME, 'true', 1)
  }

  #setCookie (name, value, days) {
    const expires = new Date()
    expires.setTime(expires.getTime() + days * ONE_MONTH)
    document.cookie =
      name +
      '=' +
      encodeURIComponent(value) +
      ';expires=' +
      expires.toUTCString() +
      ';path=/'
  }

  get isDismissed () {
    return document.cookie.includes(`${COOKIE_NAME}=true`)
  }
}
