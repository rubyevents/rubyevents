import { defineConfig } from 'vite'
import ViteRails from 'vite-plugin-rails'

export default defineConfig({
  plugins: [
    ViteRails({
      fullReload: {
        additionalPaths: [
          'config/routes.rb',
          'app/views/**/*',
          'app/controllers/**/*',
          'app/models/**/*'
        ]
      }
    })
  ],
  build: {
    // PARALLEL TEST EXECUTION FIX:
    // In test mode, disable emptyOutDir (set to false) to prevent race conditions when
    // multiple test processes run in parallel. When multiple workers try to clear the
    // same directory simultaneously, it causes ENOTEMPTY errors.
    //
    // Solution: The Vite assets are built ONCE before tests via:
    //   `bin/vite build --clear --mode=test`
    // Then all 8 test workers reuse the cached assets without rebuilding.
    //
    // This works together with config/vite.json setting `autoBuild: false` for test mode,
    // which prevents ViteRuby from triggering builds during parallel test execution.
    emptyOutDir: process.env.RAILS_ENV !== 'test'
  }
})
