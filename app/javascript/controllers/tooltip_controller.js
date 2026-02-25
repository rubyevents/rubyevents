import { Controller } from '@hotwired/stimulus'

import tippy from 'tippy.js'
import 'tippy.js/dist/tippy.css'

// Connects to data-controller="tooltip"
export default class extends Controller {
  static values = {
    content: String
  }

  connect () {
    tippy(this.element, { content: this.contentValue })
  }
}
