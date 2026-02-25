import { Application } from '@hotwired/stimulus'
import { appsignal } from '~/support/appsignal'

import HwComboboxController from '@josefarias/hotwire_combobox'

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Error handling
const defaultErrorHandler = application.handleError.bind(application)

// create a ne composed error handler with Appsignal
const appsignalErrorHandler = (error, message, detail = {}) => {
  defaultErrorHandler(error, message, detail)
  appsignal.sendError(error, (span) => { span.setTags({ message }) })
}

// overwrite the default handler with our new composed handler
application.handleError = appsignalErrorHandler

application.register('hw-combobox', HwComboboxController)

export { application }
