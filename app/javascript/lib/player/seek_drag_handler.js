export class SeekDragHandler {
  constructor (options = {}) {
    this.progressContainer = options.progressContainer
    this.progressBar = options.progressBar
    this.progressHandle = options.progressHandle
    this.seekTooltip = options.seekTooltip
    this.getDuration = options.getDuration || (() => 0)
    this.onSeek = options.onSeek || (() => {})
    this.formatTime = options.formatTime || this.defaultFormatTime.bind(this)

    this.isDragging = false
    this.dragPercent = 0
    this.dragProgressContainer = null

    this.onDragMove = this.onDragMove.bind(this)
    this.onDragEnd = this.onDragEnd.bind(this)
  }

  startDrag (event) {
    event.preventDefault()

    this.isDragging = true
    this.dragProgressContainer = this.progressContainer
    this.dragProgressContainer?.classList.add('dragging')

    document.addEventListener('mousemove', this.onDragMove)
    document.addEventListener('mouseup', this.onDragEnd)
    document.addEventListener('touchmove', this.onDragMove)
    document.addEventListener('touchend', this.onDragEnd)

    this.onDragMove(event)

    this.seekTooltip?.classList.add('visible')
  }

  onDragMove (event) {
    if (!this.isDragging || !this.dragProgressContainer) return

    const clientX = event.touches ? event.touches[0].clientX : event.clientX
    const rect = this.dragProgressContainer.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width))
    this.dragPercent = percent

    const duration = this.getDuration()
    const seekTime = percent * duration

    if (this.progressBar) {
      this.progressBar.style.width = `${percent * 100}%`
    }

    if (this.progressHandle) {
      this.progressHandle.style.left = `${percent * 100}%`
    }

    if (this.seekTooltip) {
      this.seekTooltip.textContent = this.formatTime(seekTime)
      this.seekTooltip.style.left = `${percent * 100}%`
    }
  }

  async onDragEnd () {
    if (!this.isDragging) return

    document.removeEventListener('mousemove', this.onDragMove)
    document.removeEventListener('mouseup', this.onDragEnd)
    document.removeEventListener('touchmove', this.onDragMove)
    document.removeEventListener('touchend', this.onDragEnd)

    this.seekTooltip?.classList.remove('visible')
    this.dragProgressContainer?.classList.remove('dragging')

    const duration = this.getDuration()
    const seekTime = this.dragPercent * duration

    this.onSeek(seekTime)

    this.isDragging = false
    this.dragProgressContainer = null
  }

  seekToPosition (event) {
    const rect = this.progressContainer.getBoundingClientRect()
    const percent = (event.clientX - rect.left) / rect.width
    const duration = this.getDuration()
    const seekTime = percent * duration

    this.onSeek(seekTime)
  }

  showSeekPreview (event) {
    if (this.isDragging || !this.seekTooltip) return

    const rect = this.progressContainer.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    const duration = this.getDuration()
    const seekTime = percent * duration

    this.seekTooltip.textContent = this.formatTime(seekTime)
    this.seekTooltip.style.left = `${percent * 100}%`
    this.seekTooltip.classList.add('visible')
  }

  hideSeekPreview () {
    if (this.isDragging || !this.seekTooltip) return

    this.seekTooltip.classList.remove('visible')
  }

  defaultFormatTime (seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)

    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
}
