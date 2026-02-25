import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['previewView', 'listView', 'previewButton', 'listButton']
  static values = { storageKey: { type: String, default: 'events-view-preference' } }

  connect () {
    const savedView = window.localStorage.getItem(this.storageKeyValue) || 'preview'
    this.switchTo(savedView)
  }

  showPreview () {
    this.switchTo('preview')
  }

  showList () {
    this.switchTo('list')
  }

  switchTo (view) {
    window.localStorage.setItem(this.storageKeyValue, view)

    if (view === 'preview') {
      this.previewViewTarget.classList.remove('hidden')
      this.listViewTarget.classList.add('hidden')
      this.previewButtonTarget.classList.add('tab-active')
      this.listButtonTarget.classList.remove('tab-active')
    } else {
      this.previewViewTarget.classList.add('hidden')
      this.listViewTarget.classList.remove('hidden')
      this.previewButtonTarget.classList.remove('tab-active')
      this.listButtonTarget.classList.add('tab-active')
    }
  }
}
