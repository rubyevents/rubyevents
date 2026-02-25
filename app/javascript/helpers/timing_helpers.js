export function nextEventLoopTick () {
  return delay(0)
}

export function onNextEventLoopTick (callback) {
  setTimeout(callback, 0)
}

export function nextFrame () {
  return new Promise(requestAnimationFrame)
}

export function nextEventNamed (eventName, element = window) {
  return new Promise(resolve => element.addEventListener(eventName, resolve, { once: true }))
}

export function delay (ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}
