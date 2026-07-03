import { Controller } from '@hotwired/stimulus'

const MENTIONS = [
  { at: 8, type: 'Topic', icon: '🏷️', name: 'Hotwire', start: 8 },
  { at: 22, type: 'Person', icon: '👤', name: 'Aaron Patterson', start: 22 },
  { at: 40, type: 'Link', icon: '🔗', name: 'github.com/rails/rails', start: 40 },
  { at: 60, type: 'Talk', icon: '▶️', name: 'The Rails World 2023 Keynote', start: 60 }
]

const WINDOW = 6

export default class extends Controller {
  static targets = ['card', 'icon', 'type', 'name']

  connect () {
    this.shownAt = null
    this.currentStart = null
  }

  timeUpdate (event) {
    const time = event.detail.time
    if (time == null) return

    const mention = MENTIONS.find((m) => time >= m.at && time < m.at + WINDOW)

    if (!mention) {
      if (this.shownAt !== null) this.hide()
      return
    }

    if (this.shownAt === mention.at) return

    this.show(mention)
  }

  show (mention) {
    this.shownAt = mention.at
    this.currentStart = mention.start
    this.iconTarget.textContent = mention.icon
    this.typeTarget.textContent = mention.type
    this.nameTarget.textContent = mention.name

    this.cardTarget.classList.remove('opacity-0', 'translate-y-2', 'pointer-events-none')
  }

  hide () {
    this.shownAt = null
    this.cardTarget.classList.add('opacity-0', 'translate-y-2', 'pointer-events-none')
  }

  jump () {
    if (this.currentStart == null) return
    this.dispatch('seek', { target: window, prefix: 'transcript', detail: { time: this.currentStart } })
  }
}
