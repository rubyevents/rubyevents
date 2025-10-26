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
    // In test mode, disable emptyOutDir to prevent race conditions when
    // multiple test processes run in parallel. The output directory should
    // be cleaned once before tests via `bin/vite build --clear --mode=test`.
    emptyOutDir: process.env.RAILS_ENV !== 'test'
  }
})
