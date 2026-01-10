import { Turbo } from '@hotwired/turbo-rails'

Turbo.StreamActions.update_value = function () {
  const target = this.targetElements[0]
  if (!target) return

  const attribute = this.getAttribute('attribute')
  const value = this.getAttribute('value')

  if (attribute && target) {
    target.setAttribute(attribute, value)
  }
}
