import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "event", "group"]
  static values = { current: { type: String, default: "all" } }

  filter(event) {
    this.currentValue = event.currentTarget.dataset.kind
  }

  currentValueChanged() {
    this.updateButtons()
    this.filterEvents()
    this.updateGroups()
  }

  updateButtons() {
    this.buttonTargets.forEach(button => {
      const isActive = button.dataset.kind === this.currentValue
      button.classList.toggle("btn-active", isActive)
      button.classList.toggle("btn-primary", isActive)
    })
  }

  filterEvents() {
    this.eventTargets.forEach(event => {
      const eventKind = event.dataset.kind
      const shouldShow = this.currentValue === "all" || eventKind === this.currentValue
      event.classList.toggle("hidden", !shouldShow)
    })
  }

  updateGroups() {
    this.groupTargets.forEach(group => {
      const visibleEvents = group.querySelectorAll('[data-events-filter-target="event"]:not(.hidden)')
      group.classList.toggle("hidden", visibleEvents.length === 0)
    })
  }
}
