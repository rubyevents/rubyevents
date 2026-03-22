import { Formatter } from './formatter.mjs'

const files = process.argv.slice(2).filter(file => file.endsWith('.yml'))

if (files.length === 0) {
  console.error('Usage: node yaml/enforce_strings_files.mjs <file1.yml> [file2.yml ...]')
  process.exit(1)
}

files.forEach(file => {
  console.log(`Enforcing Strings: ${file}`)
  const formatter = new Formatter(file)
  formatter.format()
})
