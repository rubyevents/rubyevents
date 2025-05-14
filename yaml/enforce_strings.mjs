import fs from 'fs'
import { Formatter } from './formatter.mjs'

const videos = fs.readdirSync('./data', { recursive: true }).filter(file => file.endsWith('videos.yml'))

videos.forEach(video => {
  const formatter = new Formatter(`./data/${video}`)
  formatter.format()
})
