import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { talkId: String }
  static targets = ['form']

  connect () {
    this.formTargets.forEach(form => {
      form.addEventListener('submit', this.addPlayingState.bind(this))
    })
  }

  addPlayingState (event) {
    const form = event.target
    const playerContainer = document.getElementById(this.talkIdValue)

    if (playerContainer) {
      const isPlaying = playerContainer.classList.contains('playing') ||
                        playerContainer.querySelector('.custom-player-wrapper.video-started') !== null

      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = 'video_playing'
      input.value = isPlaying ? '1' : '0'
      form.appendChild(input)
    }
  }
}
