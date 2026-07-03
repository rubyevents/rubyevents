import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button', 'none']
  static classes = ['active']
  static values = {
    kind: {
      type: String,
      default: 'all'
    },
    language: {
      type: String,
      default: 'all'
    }
  }

  selectKind (event) {
    const target = (event.target.dataset.kindValue) ? event.target : event.target.closest('[data-kind-value]')

    if (!target) return

    const value = target.dataset.kindValue
    this.kindValue = (this.kindValue === value) ? 'all' : value
  }

  selectLanguage (event) {
    const target = (event.target.dataset.languageValue) ? event.target : event.target.closest('[data-language-value]')

    if (!target) return

    const value = target.dataset.languageValue
    this.languageValue = (this.languageValue === value) ? 'all' : value
  }

  kindValueChanged () {
    this.updateFilterResult()
  }

  languageValueChanged () {
    this.updateFilterResult()
  }

  updateFilterResult () {
    this.buttonTargets.forEach(button => button.classList.remove(...this.activeClasses))
    this.buttonTargets.find(button => button.dataset.languageValue === this.languageValue)?.classList.add(...this.activeClasses)
    this.buttonTargets.find(button => button.dataset.kindValue === this.kindValue)?.classList.add(...this.activeClasses)

    document.querySelectorAll('.talk-all').forEach(talk => talk.classList.add('hidden'))
    this.element.querySelectorAll('.count').forEach(talk => talk.classList.add('hidden'))

    this.element.querySelectorAll(`.count-kind.count-language-${this.languageValue}`).forEach(talk => talk.classList.remove('hidden'))
    this.element.querySelectorAll(`.count-language.count-kind-${this.kindValue}`).forEach(talk => talk.classList.remove('hidden'))

    const matchingTalks = document.querySelectorAll(`.talk-kind-${this.kindValue}.talk-language-${this.languageValue}`)
    matchingTalks.forEach(talk => talk.classList.remove('hidden'))

    if (matchingTalks.length === 0) {
      this.noneTarget.classList.remove('hidden')
    } else {
      this.noneTarget.classList.add('hidden')
    }
  }
}
