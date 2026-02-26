// Example: Load Rails libraries in Vite.
//
import '@hotwired/turbo-rails'

// import ActiveStorage from "@rails/activestorage";
// ActiveStorage.start();
//
// // Import all channels.
// const channels = import.meta.globEager('./**/*_channel.js')

import '~/controllers'

import ahoy from 'ahoy.js'

ahoy.trackView()
ahoy.trackClicks('a, button, input[type=submit]')
ahoy.trackSubmits('form')
ahoy.trackChanges('input, textarea, select')
