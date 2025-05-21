import { Controller } from '@hotwired/stimulus'
import { useDebounce } from 'stimulus-use'
import Combobox from '@github/combobox-nav'
import { get } from '@rails/request.js'

// Connects to data-controller="spotlight-search"
export default class extends Controller {
  static targets = ['searchInput', 'form', 'searchResults', 'talksSearchResults',
    'speakersSearchResults', 'eventsSearchResults', 'allSearchResults',
    'searchQuery', 'loading', 'clear']

  static debounces = ['search']
  static values = {
    urlSpotlightTalks: String,
    urlSpotlightSpeakers: String,
    urlSpotlightEvents: String,
    mainResource: String
  }

  // lifecycle
  initialize () {
    useDebounce(this, { wait: 100 })
    this.dialog.addEventListener('modal:open', this.appear.bind(this))
    this.combobox = new Combobox(this.searchInputTarget, this.searchResultsTarget)
    this.combobox.start()
  }

  connect () {}

  disconnect () {
    this.dialog.removeEventListener('modal:open', this.appear.bind(this))
    this.combobox.stop()
  }

  // actions

  async search () {
    const query = this.searchInputTarget.value

    if (query.length === 0) {
      this.#clearResults()
      this.#toggleClearing()
      return
    }

    this.allSearchResultsTarget.classList.remove('hidden')
    this.searchQueryTarget.innerHTML = query
    this.loadingTarget.classList.remove('hidden')
    this.clearTarget.classList.add('hidden')

    const searchPromises = []

    // search talks and abort previous requests
    if (this.hasUrlSpotlightTalksValue) {
      if (this.talksAbortController) {
        this.talksAbortController.abort()
      }
      this.talksAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightTalksValue, query, this.talksAbortController))
    }

    // search speakers and abort previous requests
    if (this.hasUrlSpotlightSpeakersValue) {
      if (this.speakersAbortController) {
        this.speakersAbortController.abort()
      }
      this.speakersAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightSpeakersValue, query, this.speakersAbortController))
    }

    // search events and abort previous requests
    if (this.hasUrlSpotlightEventsValue) {
      if (this.eventsAbortController) {
        this.eventsAbortController.abort()
      }
      this.eventsAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightEventsValue, query, this.eventsAbortController))
    }

    try {
      await Promise.all(searchPromises)
    } finally {
      this.loadingTarget.classList.add('hidden')
      this.#toggleClearing()
    }
  }

  navigate () {
    if (this.selectedOption?.matches('a, [href]')) {
      this.selectedOption.click()
    } else {
      requestAnimationFrame(() => {
        const url = new URL(`/${this.mainResourceValue}`, window.location.origin)
        url.searchParams.set('s', this.searchInputTarget.value)
        window.location.href = url.toString()
      })
    }
  }

  clear () {
    this.searchInputTarget.value = ''
    this.#clearResults()
    this.#toggleClearing()
    this.searchInputTarget.focus()
  }

  // callbacks
  appear () {
    console.log('appear', this.searchInputTarget)
    requestAnimationFrame(() => {
      this.searchInputTarget.focus()
    })
  }

  // private
  #handleSearch (url, query, abortController) {
    return get(url, {
      query: { s: query },
      responseKind: 'turbo-stream',
      headers: {
        'Turbo-Frame': 'talks_search_results'
      },
      signal: abortController.signal
    }).catch(error => {
      // Ignore abort errors, but rethrow other errors
      if (error.name !== 'AbortError') {
        throw error
      }
    })
  }

  #clearResults () {
    if (this.talksAbortController) {
      this.talksAbortController.abort()
    }

    if (this.speakersAbortController) {
      this.speakersAbortController.abort()
    }

    if (this.eventsAbortController) {
      this.eventsAbortController.abort()
    }
    this.talksSearchResultsTarget.innerHTML = ''
    this.speakersSearchResultsTarget.innerHTML = ''
    this.eventsSearchResultsTarget.innerHTML = ''
    this.allSearchResultsTarget.classList.add('hidden')
  }

  #toggleClearing () {
    const query = this.searchInputTarget.value
    if (query.length === 0) {
      this.clearTarget.classList.add('hidden')
    } else {
      this.clearTarget.classList.remove('hidden')
    }
  }

  // getters
  get dialog () {
    return this.element.closest('dialog')
  }

  get selectedOption () {
    return this.searchResultsTarget.querySelector('[aria-selected="true"]')
  }
}
