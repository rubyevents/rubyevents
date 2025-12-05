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
          'app/models/**/*',
          'tmp/vite-reload'
        ]
      }
    })
  ],
  server: {
    watch: {
      ignored: ['**/data/**']
    }
  }
})
