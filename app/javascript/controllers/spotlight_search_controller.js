import { Controller } from '@hotwired/stimulus'
import { useDebounce } from 'stimulus-use'
import Combobox from '@github/combobox-nav'
import { get } from '@rails/request.js'

// Connects to data-controller="spotlight-search"
export default class extends Controller {
  static targets = ['searchInput', 'form', 'searchResults', 'talksSearchResults',
    'speakersSearchResults', 'eventsSearchResults', 'topicsSearchResults', 'seriesSearchResults',
    'organizationsSearchResults', 'locationsSearchResults', 'languagesSearchResults', 'allSearchResults', 'searchQuery', 'loading', 'clear', 'searchBackendBadge', 'backendToggle', 'sqliteBadge', 'typesenseBadge']

  static debounces = ['search']
  static values = {
    urlSpotlightTalks: String,
    urlSpotlightSpeakers: String,
    urlSpotlightEvents: String,
    urlSpotlightTopics: String,
    urlSpotlightSeries: String,
    urlSpotlightOrganizations: String,
    urlSpotlightLocations: String,
    urlSpotlightLanguages: String,
    mainResource: String
  }

  // lifecycle
  initialize () {
    useDebounce(this, { wait: 100 })
    this.dialog.addEventListener('modal:open', this.appear.bind(this))
    this.combobox = new Combobox(this.searchInputTarget, this.searchResultsTarget)
    this.combobox.start()
    this.defaultsLoaded = false
    this.#initBackendToggle()
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
      this.#loadDefaults()
      this.#toggleClearing()
      return
    }

    if (this.defaultsAbortController) {
      this.defaultsAbortController.abort()
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

    // search topics and abort previous requests
    if (this.hasUrlSpotlightTopicsValue) {
      if (this.topicsAbortController) {
        this.topicsAbortController.abort()
      }
      this.topicsAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightTopicsValue, query, this.topicsAbortController))
    }

    // search series and abort previous requests
    if (this.hasUrlSpotlightSeriesValue) {
      if (this.seriesAbortController) {
        this.seriesAbortController.abort()
      }
      this.seriesAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightSeriesValue, query, this.seriesAbortController))
    }

    // search organizations and abort previous requests
    if (this.hasUrlSpotlightOrganizationsValue) {
      if (this.organizationsAbortController) {
        this.organizationsAbortController.abort()
      }
      this.organizationsAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightOrganizationsValue, query, this.organizationsAbortController))
    }

    // search locations and abort previous requests
    if (this.hasUrlSpotlightLocationsValue) {
      if (this.locationsAbortController) {
        this.locationsAbortController.abort()
      }
      this.locationsAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightLocationsValue, query, this.locationsAbortController))
    }

    // search languages and abort previous requests
    if (this.hasUrlSpotlightLanguagesValue) {
      if (this.languagesAbortController) {
        this.languagesAbortController.abort()
      }
      this.languagesAbortController = new AbortController()
      searchPromises.push(this.#handleSearch(this.urlSpotlightLanguagesValue, query, this.languagesAbortController))
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
    this.#loadDefaults()
    this.#toggleClearing()
    this.searchInputTarget.focus()
  }

  setBackend (event) {
    const backend = event.currentTarget.dataset.backend
    this.searchBackend = backend

    this.#updateBackendBadges(backend)
    this.#clearResults()
    this.#loadDefaults()

    if (this.searchInputTarget.value.length > 0) {
      this.search()
    }
  }

  // callbacks
  appear () {
    this.searchInputTarget.focus()
    this.#loadDefaults()
  }

  // private
  async #loadDefaults () {
    if (this.defaultsAbortController) {
      this.defaultsAbortController.abort()
    }

    this.defaultsAbortController = new AbortController()
    this.allSearchResultsTarget.classList.add('hidden')

    const defaultPromises = []

    if (this.hasUrlSpotlightTalksValue) {
      defaultPromises.push(get(this.urlSpotlightTalksValue, {
        responseKind: 'turbo-stream',
        signal: this.defaultsAbortController.signal
      }).catch(() => {}))
    }

    if (this.hasUrlSpotlightSpeakersValue) {
      defaultPromises.push(get(this.urlSpotlightSpeakersValue, {
        responseKind: 'turbo-stream',
        signal: this.defaultsAbortController.signal
      }).catch(() => {}))
    }

    if (this.hasUrlSpotlightEventsValue) {
      defaultPromises.push(get(this.urlSpotlightEventsValue, {
        responseKind: 'turbo-stream',
        signal: this.defaultsAbortController.signal
      }).catch(() => {}))
    }

    await Promise.all(defaultPromises)
    this.defaultsLoaded = true
  }

  #handleSearch (url, query, abortController) {
    const params = { s: query }
    if (this.searchBackend) {
      params.search_backend = this.searchBackend
    }

    return get(url, {
      query: params,
      responseKind: 'turbo-stream',
      headers: {
        'Turbo-Frame': 'talks_search_results'
      },
      signal: abortController.signal
    }).then(response => {
      if (this.hasSearchBackendBadgeTarget) {
        const backend = response.headers.get('X-Search-Backend')

        if (backend === 'sqlite_fts') {
          this.searchBackendBadgeTarget.classList.remove('hidden')
        } else {
          this.searchBackendBadgeTarget.classList.add('hidden')
        }
      }
    }).catch(error => {
      if (error.name !== 'AbortError') {
        throw error
      }
    })
  }

  #clearResults () {
    if (this.defaultsAbortController) {
      this.defaultsAbortController.abort()
    }

    if (this.talksAbortController) {
      this.talksAbortController.abort()
    }

    if (this.speakersAbortController) {
      this.speakersAbortController.abort()
    }

    if (this.eventsAbortController) {
      this.eventsAbortController.abort()
    }

    if (this.topicsAbortController) {
      this.topicsAbortController.abort()
    }

    if (this.seriesAbortController) {
      this.seriesAbortController.abort()
    }

    if (this.organizationsAbortController) {
      this.organizationsAbortController.abort()
    }

    if (this.locationsAbortController) {
      this.locationsAbortController.abort()
    }

    if (this.languagesAbortController) {
      this.languagesAbortController.abort()
    }

    this.talksSearchResultsTarget.innerHTML = ''
    this.speakersSearchResultsTarget.innerHTML = ''
    this.eventsSearchResultsTarget.innerHTML = ''

    if (this.hasTopicsSearchResultsTarget) {
      this.topicsSearchResultsTarget.innerHTML = ''
      this.topicsSearchResultsTarget.classList.add('hidden')
    }

    if (this.hasSeriesSearchResultsTarget) {
      this.seriesSearchResultsTarget.innerHTML = ''
      this.seriesSearchResultsTarget.classList.add('hidden')
    }

    if (this.hasOrganizationsSearchResultsTarget) {
      this.organizationsSearchResultsTarget.innerHTML = ''
      this.organizationsSearchResultsTarget.classList.add('hidden')
    }

    if (this.hasLocationsSearchResultsTarget) {
      this.locationsSearchResultsTarget.innerHTML = ''
      this.locationsSearchResultsTarget.classList.add('hidden')
    }

    if (this.hasLanguagesSearchResultsTarget) {
      this.languagesSearchResultsTarget.innerHTML = ''
      this.languagesSearchResultsTarget.classList.add('hidden')
    }

    this.allSearchResultsTarget.classList.add('hidden')

    if (this.hasSearchBackendBadgeTarget) {
      this.searchBackendBadgeTarget.classList.add('hidden')
    }
  }

  #toggleClearing () {
    const query = this.searchInputTarget.value
    if (query.length === 0) {
      this.clearTarget.classList.add('hidden')
    } else {
      this.clearTarget.classList.remove('hidden')
    }
  }

  #initBackendToggle () {
    if (!this.hasSqliteBadgeTarget) return

    this.searchBackend = 'sqlite'
    this.#updateBackendBadges(this.searchBackend)
  }

  #updateBackendBadges (backend) {
    if (!this.hasSqliteBadgeTarget) return

    if (backend === 'sqlite') {
      this.sqliteBadgeTarget.classList.add('badge-warning')
      this.sqliteBadgeTarget.classList.remove('badge-ghost')
      this.typesenseBadgeTarget.classList.remove('badge-primary')
      this.typesenseBadgeTarget.classList.add('badge-ghost')
    } else {
      this.typesenseBadgeTarget.classList.add('badge-primary')
      this.typesenseBadgeTarget.classList.remove('badge-ghost')
      this.sqliteBadgeTarget.classList.remove('badge-warning')
      this.sqliteBadgeTarget.classList.add('badge-ghost')
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
