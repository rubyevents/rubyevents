import fs from 'fs'
import YAML, { parseDocument } from 'yaml'

// Formatting YAML with Ruby doesn't work well with Emojis, so we're falling back to good ol' JS
//
// See https://github.com/rubyevents/rubyevents/pull/656
class Formatter {
  constructor (path) {
    this.path = path
  }

  format () {
    const file = fs.readFileSync(this.path, 'utf8')
    const document = parseDocument(file)

    const options = {
      indent: 2,
      lineWidth: 180,
      simpleKeys: true,
      singleQuote: false,
      collectionStyle: 'block',
      blockQuote: 'literal',
      defaultStringType: 'QUOTE_DOUBLE',
      directives: true,
      doubleQuotedMinMultiLineLength: 80
    }

    YAML.visit(document, {
      Pair (_, pair) {
        const { key, value } = pair

        const isValueString = typeof value.value === 'string'
        const isValuePlain = value.type === 'PLAIN'
        const isDescription = key.value === 'description'

        if (isValueString && isValuePlain) {
          pair.value.type = 'QUOTE_DOUBLE'
        }

        if (isDescription && isValueString) {
          pair.value.type = 'BLOCK_LITERAL'
        }
      }
    })

    fs.writeFileSync(this.path, document.toString(options))
  }
}

let filesToFormat = []

if (process.argv.length > 2) {
  filesToFormat = process.argv.slice(2)
} else {
  const videos = fs.readdirSync('./data', { recursive: true }).filter(file => file.endsWith('videos.yml'))
  filesToFormat = videos.map(video => `./data/${video}`)
}

filesToFormat.forEach(filePath => {
  const formatter = new Formatter(filePath)
  formatter.format()
})
