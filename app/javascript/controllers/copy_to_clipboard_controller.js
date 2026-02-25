import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button', 'source']
  static values = {
    successMessage: { type: String, default: 'Copied!' },
    successDuration: { type: Number, default: 2000 }
  }

  static classes = ['success']

  async copy (event) {
    event.preventDefault()

    const text = this.sourceTarget.innerText

    try {
      if (navigator.clipboard) {
        await navigator.clipboard.writeText(text)
      } else {
        this.fallbackCopy(text)
      }
      this.copied()
    } catch (error) {
      this.fallbackCopy(text)
      this.copied()
    }
  }

  fallbackCopy (text) {
    const temporaryInput = document.createElement('textarea')
    temporaryInput.value = text
    document.body.appendChild(temporaryInput)
    temporaryInput.select()
    document.execCommand('copy')
    document.body.removeChild(temporaryInput)
  }

  copied () {
    if (!this.hasButtonTarget) return

    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    const successClass = this.successClass
    if (successClass) {
      this.buttonTarget.classList.add(successClass)
    }
    const message = this.successMessageValue
    const originalText = this.buttonTarget.innerHTML
    if (message) {
      this.buttonTarget.innerHTML = message
    }

    this.timeout = setTimeout(() => {
      this.buttonTarget.classList.remove(successClass)
      this.buttonTarget.innerHTML = originalText
    }, this.successDurationValue)
  }
}
