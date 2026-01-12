import fs from 'fs'
import { Formatter } from './formatter.mjs'

const files = fs.readdirSync('./data', { recursive: true }).filter(file => file.endsWith('.yml'))

files.forEach(file => {
  console.log(`Enforcing Strings: ${file}`)
  const formatter = new Formatter(`./data/${file}`)
  formatter.format()
})
