import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="tabs"
export default class extends Controller {
  static values = { activeIndex: { type: Number, default: 0 } }

  initialize () {
    if (!this.hasActiveIndexValue) {
      const index = Array.from(this.tabs).findIndex(tab => tab.getAttribute('aria-selected') === 'true' || tab.classList.contains('tab-active'))
      this.activeIndexValue = index
    }
  }

  showPanel (e) {
    const index = Array.from(this.tabs).indexOf(e.currentTarget)
    this.activeIndexValue = index
  }

  activeIndexValueChanged () {
    this.#togglePanel()
  }

  // private

  #togglePanel () {
    this.tabs.forEach(tab => {
      const isSelected = tab === this.activeTab
      tab.setAttribute('aria-selected', isSelected)
      document.startViewTransition(() => {
        tab.classList.toggle('tab-active', isSelected)
      })
    })
  }

  get tabPanels () {
    return this.element.querySelectorAll('[role="tabpanel"]')
  }

  get tabs () {
    return this.element.querySelectorAll('[role="tab"]')
  }

  get activeTab () {
    return this.tabs[this.activeIndexValue]
  }
}
