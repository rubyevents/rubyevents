import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  regenerateAll () {
    window.dispatchEvent(new CustomEvent('thumbnails:regenerate-all'))
  }
}
