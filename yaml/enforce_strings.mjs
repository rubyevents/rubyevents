import fs from 'fs'
import { Formatter } from './formatter.mjs'

const files = []
const paths = []
if (process.argv.length > 2) {
  process.argv.slice(2).forEach((path) => {
    paths.push(path)
  })
} else {
  paths.push('./data')
}

paths.forEach((path) => {
  if (path.endsWith('/')) {
    path = path.slice(0, -1)
  }
  if (fs.existsSync(path)) {
    if (fs.lstatSync(path).isDirectory()) {
      fs.readdirSync(path, { recursive: true })
        .filter((file) => file.endsWith('.yml'))
        .forEach((file) => files.push(`${path}/${file}`))
    } else if (path.endsWith('.yml')) {
      files.push(path)
    } else {
      console.log(`Ignoring ${path} as it's not yaml`)
    }
  } else {
    console.log(`Ignoring ${path} as it doesn't exist`)
  }
})

files.forEach((file) => {
  console.log(`Enforcing Strings: ${file}`)
  const formatter = new Formatter(file)
  formatter.format()
})
