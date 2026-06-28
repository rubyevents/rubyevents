import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['view', 'button']
  static values = { storageKey: { type: String, default: 'events-view-preference' } }

  connect () {
    const savedView = window.localStorage.getItem(this.storageKeyValue) || 'preview'
    this.switchTo(savedView)
  }

  show (event) {
    const view = event.params.view
    this.switchTo(view)
  }

  switchTo (view) {
    const viewTarget = this.viewTargets.find(
      (target) => target.dataset.eventsViewSwitcherViewParam === view
    )

    if (!viewTarget) {
      this.switchTo('preview')
      return
    }

    window.localStorage.setItem(this.storageKeyValue, view)

    this.viewTargets.forEach((target) => target.classList.add('hidden'))
    this.buttonTargets.forEach((target) => target.classList.remove('tab-active'))

    viewTarget.classList.remove('hidden')

    const buttonTarget = this.buttonTargets.find(
      (target) => target.dataset.eventsViewSwitcherViewParam === view
    )

    if (buttonTarget) {
      buttonTarget.classList.add('tab-active')
    }
  }
}
