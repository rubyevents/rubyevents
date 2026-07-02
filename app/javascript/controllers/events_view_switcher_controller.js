import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['previewButton', 'listButton', 'previewView', 'listView']
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
    const isList = view === 'list'

    window.localStorage.setItem(this.storageKeyValue, isList ? 'list' : 'preview')

    if (this.hasPreviewViewTarget) {
      this.previewViewTarget.classList.toggle('hidden', isList)
    }

    if (this.hasListViewTarget) {
      this.listViewTarget.classList.toggle('hidden', !isList)
    }

    if (this.hasPreviewButtonTarget) {
      this.previewButtonTarget.classList.toggle('tab-active', !isList)
    }

    if (this.hasListButtonTarget) {
      this.listButtonTarget.classList.toggle('tab-active', isList)
    }
  }
}
