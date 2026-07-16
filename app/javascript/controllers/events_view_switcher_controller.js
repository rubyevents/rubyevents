import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['view', 'button']
  static values = { storageKey: { type: String, default: 'events-view-preference' } }

  connect () {
    this.switchTo(window.localStorage.getItem(this.storageKeyValue))
  }

  show (event) {
    this.switchTo(event.params.view)
  }

  switchTo (view) {
    const requested = this.viewTargets.find(
      (target) => target.dataset.eventsViewSwitcherViewParam === view
    )

    const target = requested || this.viewTargets[0]
    if (!target) return

    const activeView = target.dataset.eventsViewSwitcherViewParam

    window.localStorage.setItem(this.storageKeyValue, activeView)

    this.viewTargets.forEach((viewTarget) => {
      viewTarget.classList.toggle('hidden', viewTarget !== target)
    })

    this.buttonTargets.forEach((button) => {
      const isActive = button.dataset.eventsViewSwitcherViewParam === activeView
      button.classList.toggle('tab-active', isActive)
    })
  }
}
