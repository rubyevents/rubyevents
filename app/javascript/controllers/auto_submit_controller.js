import { Controller } from '@hotwired/stimulus'
import { useDebounce } from 'stimulus-use'

export default class extends Controller {
  static debounces = ['submit']
  static values = { wait: { type: Number, default: 350 } }

  initialize () {
    useDebounce(this, { wait: this.waitValue })

    this.element.addEventListener('keydown', () => this.submit())
    this.element.addEventListener('search', () => this.submit())
  }

  disconnect () {
    this.element.removeEventListener('keydown', () => this.submit())
    this.element.removeEventListener('search', () => this.submit())
  }

  submit () {
    this.element.requestSubmit()
  }
}
