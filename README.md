# RubyEvents.org (formerly RubyVideo.dev)

[RubyEvents.org](https://www.rubyevents.org) (formerly RubyVideo.dev), inspired by [pyvideo.org](https://pyvideo.org/), is designed to index all Ruby-related events and videos from conferences and meetups around the world. At the time of writing, the project has 6000+ videos indexed from 200+ events and 3000+ speakers.

Technically the project is built using the latest [Ruby](https://www.ruby-lang.org/) and [Rails](https://rubyonrails.org/) goodies such as [Hotwire](https://hotwired.dev/), [Solid Queue](https://github.com/rails/solid_queue), [Solid Cache](https://github.com/rails/solid_cache).

For the front end part we use [Vite](https://vite.dev/), [Tailwind](https://tailwindcss.com/) with [daisyUI](https://daisyUI.com/) components and [Stimulus](https://stimulus.hotwire.dev/).

It is deployed on an [Hetzner](https://hetzner.cloud/?ref=gyPLk7XJthjg) VPS with [Kamal](https://kamal-deploy.org/) using [SQLite](https://www.sqlite.org/) as the main database.

For compatible browsers it tries to demonstrate some of the possibilities of [Page View Transition API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transitions_API).

## Contributing

This project is open source, and contributions are greatly appreciated. One of the most direct ways to contribute at this time is by adding more content.

We also have a page on the deployed site that has up-to-date information with the remaining known TODOs. Check out the ["Getting Started: Ways to Contribute" page on RubyEvents.org](https://www.rubyevents.org/contributions) and feel free to start working on any of the remaining TODOs. Any help is greatly appreciated.

For more information on contributing, see the [Contributing Guide](/CONTRIBUTING.md).

## Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By participating in this project, you agree to abide by its terms. More details can be found in the [Code of Conduct](/CODE_OF_CONDUCT.md) document.

## Credits

Thank you [Appsignal](https://appsignal.com/r/eeab047472) for providing the APM tool that helps us monitor the application.

## License

RubyEvents.org is open source and available under the MIT License. For more information, please see the [License](/LICENSE.md) file.
