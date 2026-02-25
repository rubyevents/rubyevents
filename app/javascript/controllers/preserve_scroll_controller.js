import { Controller } from '@hotwired/stimulus'
import { nextFrame } from '../helpers/timing_helpers'

// Connects to data-controller="preserve-scroll"
export default class extends Controller {
  async connect () {
    if (this.scrollTop) {
      await nextFrame() // we need to wait for the next frame to ensure the scroll position is set
      window.scrollTo(0, this.scrollTop)

      // remove the scrollTop from the url params
      const url = new URL(window.location)
      url.searchParams.delete('scroll_top')
      window.Turbo.navigator.history.replace(url)
    }
  }

  updateLinkBackToWithScrollPosition (e) {
    // usually invoked on an hover event, it will rewrite the back_to url with the current scroll position
    const link = e.currentTarget.href
    if (!link) return

    const url = new URL(link)
    const urlParams = url.searchParams
    const backTo = urlParams.get('back_to')
    if (!backTo) return

    // Get current scroll position
    const scrollY = parseInt(window.scrollY)

    // Create a URL object to handle the backTo path's parameters
    const backToUrl = new URL(backTo, window.location.origin)

    // Set or update the scroll_top parameter
    backToUrl.searchParams.set('scroll_top', scrollY)

    // Update the back_to parameter with the modified path + query
    urlParams.set('back_to', backToUrl.pathname + backToUrl.search)

    // Update the href with the modified URL
    e.currentTarget.href = url.toString()
  }

  get scrollTop () {
    // from url params scroll_top
    const urlParams = new URLSearchParams(window.location.search)
    return urlParams.get('scroll_top')
  }
}
