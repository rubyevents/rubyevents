import { Controller } from '@hotwired/stimulus'
import { useClickOutside } from 'stimulus-use'

// Connects to data-controller="modal"
export default class extends Controller {
  static values = {
    open: Boolean
  }

  static targets = ['modalBox']

  initialize () {
    useClickOutside(this, { element: this.modalBoxTarget })
    if (this.toggle) {
      this.toggle.addEventListener('click', () => {
        this.open()
      })
    }
  }

  connect () {
    if (this.openValue) {
      this.open()
    }
  }

  disconnect () {
    this.close()
  }

  clickOutside (event) {
    this.close()
  }

  open () {
    this.element.showModal()
    this.dispatch('open')
  }

  close (e) {
    e?.preventDefault()

    this.element.close()
  }

  // getters
  get toggle () {
    return document.querySelector(`[data-toggle="modal"][data-target="${this.element.id}"]`)
  }
}
