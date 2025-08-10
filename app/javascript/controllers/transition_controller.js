import { Controller } from '@hotwired/stimulus'
import { useTransition } from 'stimulus-use'

export default class extends Controller {
  static values = {
    enterActive: { type: String, default: 'transition ease-in duration-300' },
    enterFrom: { type: String, default: 'transform opacity-0' },
    enterTo: { type: String, default: 'transform opacity-100' },
    leaveActive: { type: String, default: 'transition ease-in duration-300' },
    leaveFrom: { type: String, default: 'transform opacity-100' },
    leaveTo: { type: String, default: 'transform opacity-0' },
    hiddenClass: { type: String, default: 'hidden' },
    transitioned: { type: Boolean, default: false },
    removeToClasses: { type: Boolean, default: false },
    enterAfter: { type: Number, default: -1 },
    leaveAfter: Number
  }

  static targets = ['content']

  connect () {
    if (this.isPreview) return

    useTransition(this, {
      element: this.elementToTransition,
      enterActive: this.enterActiveValue,
      enterFrom: this.enterFromValue,
      enterTo: this.enterToValue,
      leaveActive: this.leaveActiveValue,
      leaveFrom: this.leaveFromValue,
      leaveTo: this.leaveToValue,
      hiddenClass: this.hiddenClassValue,
      transitioned: this.transitionedValue,
      leaveAfter: this.leaveAfterValue
    })

    if (this.enterAfterValue >= 0) {
      setTimeout(() => {
        this.enter()
      }, this.enterAfterValue)
    }
  }

  // getters

  get elementToTransition () {
    return this.hasContentTarget ? this.contentTarget : this.element
  }

  get isPreview () {
    return document.documentElement.hasAttribute('data-turbo-preview')
  }
}
