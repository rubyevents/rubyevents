import fs from 'fs'
import YAML, { parseDocument } from 'yaml'

export class Formatter {
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

    if (document.errors.length > 0) {
      console.log(document.errors)
    }

    fs.writeFileSync(this.path, document.toString(options))
  }
}
