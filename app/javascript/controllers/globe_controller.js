import { Controller } from '@hotwired/stimulus'
import { useIntersection, useMatchMedia, useResize } from 'stimulus-use'
import createGlobe from 'cobe'

const TAU = Math.PI * 2
const SPIN = 0.003
const EASE = 0.08
const SWAY = 0.2
const ZOOM = 1.4
const IDLE_THETA = 0.3
const MAX_TILT = Math.PI / 2 - 0.05
const MAX_CENTER_TILT = 0.7
const DRAG_THRESHOLD = 3
const GLOBE_RADIUS = 0.8
const MARKER_COLOR = [0.86, 0.08, 0.24]
const HIGHLIGHT_COLOR = [1, 0.6, 0.7]
const MARKER_SIZE = 0.04
const HIGHLIGHT_SIZE = 0.12
const SPREAD_DISTANCE = 22
const SPREAD_RETURN = 0.1
const SPREAD_MIN_RETURN = 0.5
const SPREAD_MAX_STEP = 3
const SPREAD_SETTLED = 0.2
const DEFAULT_SETTINGS = {
  dark: 1,
  baseColor: MARKER_COLOR,
  markerColor: MARKER_COLOR,
  markerElevation: 0
}

// Connects to data-controller="globe"
export default class extends Controller {
  static targets = ['frame', 'canvas', 'marker']
  static values = { markers: Array, center: Array }

  globe = null
  animationFrame = null
  lastFrameAt = null
  size = { width: 0, height: 0 }
  scale = 1
  zoom = 1
  phi = 0
  theta = IDLE_THETA
  center = null
  swayPhase = 0
  highlighted = null
  following = false
  hovering = false
  intersecting = false
  reducedMotion = false
  drag = null

  connect () {
    if (document.documentElement.hasAttribute('data-turbo-preview')) return

    // A restored Turbo snapshot still holds cobe's wrapper and stale anchors around the canvas
    this.frameTarget.replaceChildren(this.canvasTarget)

    useMatchMedia(this, { mediaQueries: { reducedMotion: '(prefers-reduced-motion: reduce)' } })
    useIntersection(this)
    useResize(this, { element: this.frameTarget })
  }

  disconnect () {
    this.#stop()

    if (!this.globe) return

    this.globe.destroy()
    this.globe = null
    this.#loseContext()
  }

  // A Turbo morph swaps in the new markers while the running globe keeps its canvas
  markersValueChanged () {
    this.bySlug = new Map(
      this.markersValue.flatMap((marker, index) =>
        marker.events.map((event) => [event.slug, index])
      )
    )
    this.unfocus()
  }

  // A newly selected continent becomes the area the globe eases to and sways around
  centerValueChanged () {
    this.center = null
    this.following = false

    if (this.centerValue.length === 2) {
      const { phi, theta } = this.#anglesFor(...this.centerValue)

      this.center = {
        phi,
        theta: Math.max(-MAX_CENTER_TILT, Math.min(MAX_CENTER_TILT, theta))
      }
    }

    // Before the first frame, start facing the continent or the visitor's part of the world
    if (!this.globe) {
      const start = this.center || this.#localAngles

      this.phi = start.phi
      this.theta = start.theta
      this.zoom = this.#targetZoom
    }

    this.#requestFrame()
  }

  resize ({ width, height }) {
    this.size = { width: Math.round(width), height: Math.round(height) }

    if (!this.size.width || !this.size.height) return this.#stop()

    // The sphere radius follows the canvas height, so shrink it on tall canvases to keep it inside the frame
    this.scale = Math.min(1, (this.size.width / this.size.height) * 0.95)

    if (this.globe) {
      this.globe.update({ ...this.size, scale: this.#globeScale })
    } else {
      this.globe = createGlobe(this.canvasTarget, {
        ...DEFAULT_SETTINGS,
        ...this.size,
        ...this.#view,
        devicePixelRatio: this.#devicePixelRatio
      })
      this.canvasTarget.classList.remove('opacity-0')
    }

    this.#requestFrame()
  }

  appear () {
    this.intersecting = true
    this.#requestFrame()
  }

  disappear () {
    this.intersecting = false
    this.#stop()
  }

  isReducedMotion () {
    this.reducedMotion = true
    this.#requestFrame()
  }

  notReducedMotion () {
    this.reducedMotion = false
    this.#requestFrame()
  }

  skipMorph (event) {
    event.preventDefault()
  }

  // A morph resets the marker elements to their server-rendered state
  morphed () {
    this.#renderHighlight()
  }

  // Marks the event's location and rotates the globe towards it
  focus (slug) {
    this.following = this.bySlug.has(slug)
    this.#highlight(this.bySlug.get(slug), slug)
  }

  // Clears the highlight and resumes spinning
  unfocus () {
    this.following = false
    this.#highlight(null)
  }

  // Pointer over a marker highlights its most recent event
  hover ({ params: { index } }) {
    this.following = false
    this.#highlight(index, this.#eventsAt(index)[0].slug)
    this.dispatch('hover', { detail: { slug: this.highlighted.slug } })
  }

  unhover (event) {
    // A tapped event stays focused until the next tap
    if (event.pointerType === 'touch') return

    this.unfocus()
    this.dispatch('leave')
  }

  // Clicking a marker focuses its event; clicking again cycles through the events at that spot
  select ({ params: { index } }) {
    const events = this.#eventsAt(index)
    const position = events.findIndex(
      (event) => event.slug === this.highlighted?.slug
    )
    const next = this.following
      ? (position + 1) % events.length
      : Math.max(position, 0)

    this.following = true
    this.#highlight(index, events[next].slug)
    this.dispatch('select', { detail: { slug: this.highlighted.slug } })
  }

  // Pointer over the globe pauses the spin
  pause () {
    this.hovering = true
  }

  leave (event) {
    this.hovering = false
    this.#requestFrame()

    if (event.pointerType === 'touch') return

    this.unfocus()
    this.dispatch('leave')
  }

  grab (event) {
    if (event.button !== 0 || !this.globe) return

    this.drag = {
      x: event.clientX,
      y: event.clientY,
      phi: this.phi,
      theta: this.theta,
      moved: false
    }
  }

  move (event) {
    if (!this.drag) return

    const dx = event.clientX - this.drag.x
    const dy = event.clientY - this.drag.y

    if (!this.drag.moved) {
      if (Math.hypot(dx, dy) < DRAG_THRESHOLD) return

      // Capturing keeps the drag alive outside the frame and stops the click at the end from selecting a marker
      this.element.setPointerCapture(event.pointerId)
      this.drag.moved = true
      this.following = false
    }

    // Dragging across the globe's radius rotates it by one radian
    this.phi = this.#normalizeAngle(this.drag.phi + dx / this.#radius)
    this.theta = Math.max(
      -MAX_TILT,
      Math.min(MAX_TILT, this.drag.theta + dy / this.#radius)
    )
    this.#requestFrame()
  }

  drop () {
    this.drag = null
    this.#requestFrame()
  }

  get #gl () {
    return this.canvasTarget.getContext('webgl2') || this.canvasTarget.getContext('webgl')
  }

  get #devicePixelRatio () {
    return Math.min(window.devicePixelRatio || 1, 2)
  }

  get #globeScale () {
    return this.scale * this.zoom
  }

  // The sphere's on-screen radius in pixels
  get #radius () {
    return (GLOBE_RADIUS * this.#globeScale * this.size.height) / 2
  }

  get #targetZoom () {
    return this.center ? ZOOM : 1
  }

  // The free spin pauses under the pointer, during a drag and for visitors who prefer reduced motion
  get #spin () {
    return this.reducedMotion || this.hovering || this.drag ? 0 : SPIN
  }

  // Everything cobe needs to draw the current frame
  get #view () {
    return {
      phi: this.phi,
      theta: this.theta,
      scale: this.#globeScale,
      markers: this.#markers
    }
  }

  // Faces the visitor's part of the world: every hour of UTC offset is 15° of longitude
  get #localAngles () {
    const longitude = -new Date().getTimezoneOffset() / 4

    return { ...this.#anglesFor(0, longitude), theta: IDLE_THETA }
  }

  // Frees the GPU context right away instead of leaving it to garbage collection
  #loseContext () {
    this.#gl?.getExtension('WEBGL_lose_context')?.loseContext()
  }

  #requestFrame () {
    if (this.animationFrame || !this.globe || !this.intersecting) return

    this.animationFrame = window.requestAnimationFrame((now) => this.#tick(now))
  }

  #stop () {
    window.cancelAnimationFrame(this.animationFrame)
    this.animationFrame = null
    this.lastFrameAt = null
  }

  // Frames' worth of motion since the last tick, scaled to the display's frame rate and capped after a stall
  #framesSince (now) {
    const frames = this.lastFrameAt
      ? Math.min((now - this.lastFrameAt) / (1000 / 60), 3)
      : 1

    this.lastFrameAt = now

    return frames
  }

  #tick (now) {
    this.animationFrame = null

    const frames = this.#framesSince(now)
    const animating = this.#step(frames)

    this.globe.update(this.#view)

    if (this.#spreadMarkers(frames) || animating) {
      this.#requestFrame()
    } else {
      this.lastFrameAt = null
    }
  }

  // Advances the rotation, sway and zoom; returns whether another frame is needed
  #step (frames) {
    const ease = 1 - (1 - EASE) ** frames
    const spin = this.#spin
    const before = [this.phi, this.theta, this.zoom]
    let target = null

    if (this.following) {
      const { latitude, longitude } = this.markersValue[this.highlighted.index]

      target = this.#anglesFor(latitude, longitude)
    } else if (this.drag) {
      // The pointer sets the rotation
    } else if (this.center) {
      // Sway around the selected continent at the pace of the free spin, easing back to it after interactions
      this.swayPhase += (spin * frames) / SWAY
      target = {
        phi: this.center.phi + SWAY * Math.sin(this.swayPhase),
        theta: this.center.theta
      }
    } else {
      this.phi = (this.phi + spin * frames) % TAU
      target = { phi: this.phi, theta: IDLE_THETA }
    }

    if (target) {
      this.phi = this.#easeAngle(this.phi, target.phi, ease)
      this.theta += (target.theta - this.theta) * ease
    }

    this.zoom += (this.#targetZoom - this.zoom) * ease

    return (
      spin > 0 ||
      [this.phi, this.theta, this.zoom].some(
        (value, index) => Math.abs(value - before[index]) > 1e-4
      )
    )
  }

  #eventsAt (index) {
    return this.markersValue[index].events
  }

  // The marker ids let cobe anchor the avatar elements to their projected locations
  get #markers () {
    return this.markersValue.map(({ latitude, longitude }, index) => ({
      id: `marker-${index}`,
      location: [latitude, longitude],
      ...(index === this.highlighted?.index
        ? { size: HIGHLIGHT_SIZE, color: HIGHLIGHT_COLOR }
        : { size: MARKER_SIZE })
    }))
  }

  #highlight (index, slug) {
    this.highlighted = index == null ? null : { index, slug }
    this.#renderHighlight()
    this.#requestFrame()
  }

  // Scales the marker up and brings the highlighted event's avatar to the front of its stack
  #renderHighlight () {
    this.markerTargets.forEach((element, index) => {
      element.toggleAttribute('data-highlighted', index === this.highlighted?.index)

      element.querySelectorAll('img').forEach((image) => {
        image.toggleAttribute('data-current', image.dataset.slug === this.highlighted?.slug)
      })
    })
  }

  // Nudges overlapping avatars apart so nearby events stay distinguishable; returns whether any avatar moved
  #spreadMarkers (frames) {
    const origin = this.element.getBoundingClientRect()
    const points = this.markerTargets.map((element) => this.#pointFor(element, origin, frames))
    const visible = points.filter((point) => point.visible)

    // A few relaxation passes settle clusters of more than two markers
    for (let pass = 0; pass < 3; pass++) {
      for (let i = 0; i < visible.length; i++) {
        for (let j = i + 1; j < visible.length; j++) {
          this.#pushApart(visible[i], visible[j])
        }
      }
    }

    return points.map((point) => this.#applyNudge(point, frames)).some(Boolean)
  }

  // The marker's anchored position relative to the globe, and where it starts this frame: last frame's nudge
  // pulled partway back toward the anchor, so the layout carries over between frames instead of restarting
  #pointFor (element, origin, frames) {
    const rect = element.getBoundingClientRect()
    const [dx = 0, dy = 0] = element.style.translate.split(' ').map((value) => parseFloat(value) || 0)
    const anchorX = rect.x + rect.width / 2 - origin.x - dx
    const anchorY = rect.y + rect.height / 2 - origin.y - dy
    const visible = window.getComputedStyle(element).visibility === 'visible'
    const retained = this.#retained(Math.hypot(dx, dy), frames)

    return {
      element,
      visible,
      anchorX,
      anchorY,
      x: anchorX + dx * retained,
      y: anchorY + dy * retained,
      dx,
      dy
    }
  }

  // The share of a nudge that survives the pull back toward the anchor; the pull has a floor so nudges reach zero
  #retained (nudge, frames) {
    if (nudge === 0) return 0

    const pull = Math.max(SPREAD_RETURN * nudge, SPREAD_MIN_RETURN) * frames

    return Math.max(0, 1 - pull / nudge)
  }

  // Moves two points closer than the spread distance away from each other by half the shortfall each
  #pushApart (a, b) {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let distance = Math.hypot(dx, dy)

    if (distance >= SPREAD_DISTANCE) return

    // Points on the exact same spot have no direction to push along, so pick horizontal
    if (distance < 0.01) {
      dx = 1
      dy = 0
      distance = 1
    }

    const push = (SPREAD_DISTANCE - distance) / 2 / distance

    a.x -= dx * push
    a.y -= dy * push
    b.x += dx * push
    b.y += dy * push
  }

  // Writes the nudge as a translate, sliding at most a few pixels per frame; returns whether the marker moved
  #applyNudge ({ element, visible, x, y, anchorX, anchorY, dx, dy }, frames) {
    let nudgeX = visible ? x - anchorX : 0
    let nudgeY = visible ? y - anchorY : 0
    const stepX = nudgeX - dx
    const stepY = nudgeY - dy
    const step = Math.hypot(stepX, stepY)
    const maxStep = SPREAD_MAX_STEP * frames

    if (visible && step > maxStep) {
      nudgeX = dx + (stepX / step) * maxStep
      nudgeY = dy + (stepY / step) * maxStep
    }

    nudgeX = Number(nudgeX.toFixed(1))
    nudgeY = Number(nudgeY.toFixed(1))

    // Sub-pixel wobble around a settled layout isn't worth a write or another frame
    if (Math.hypot(nudgeX - dx, nudgeY - dy) < SPREAD_SETTLED) return false

    element.style.translate = `${nudgeX}px ${nudgeY}px`

    return true
  }

  // Rotation that puts the given location in front of the camera
  #anglesFor (latitude, longitude) {
    return {
      phi: this.#normalizeAngle(Math.PI * 1.5 - (longitude * Math.PI) / 180),
      theta: (latitude * Math.PI) / 180
    }
  }

  // Moves an angle towards the target along the shorter arc
  #easeAngle (current, target, factor) {
    const delta = this.#normalizeAngle(target - current + Math.PI) - Math.PI

    return this.#normalizeAngle(current + delta * factor)
  }

  #normalizeAngle (angle) {
    return ((angle % TAU) + TAU) % TAU
  }
}
