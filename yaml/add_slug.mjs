import fs from 'fs'
import YAML, { parseDocument } from 'yaml'

// File.write("slugs.json", Talk.pluck(:video_id, :slug).to_h.to_json)
const slugs = JSON.parse(fs.readFileSync('./slugs.json', 'utf8'))

export class AddSlug {
  constructor (path) {
    this.path = path
  }

  kebabize (str) {
    if (typeof str !== 'string') {
      return ''
    }

    let result = str
      .toLowerCase()
      .replace(/([a-z])([A-Z])/g, '$1-$2')
      .replace(/[\s_.:]+/g, '-')
      .replace(/[^a-z0-9-]/g, '')

    result = result.replace(/-{2,}/g, '-')
    result = result.replace(/^-+|-+$/g, '')

    return result
  }

  eventName (map) {
    const eventName = map.items.find(pair => pair.key.value === 'event_name')
    if (eventName?.value) {
      return eventName?.value?.value
    }

    const splits = this.path.split('/')
    splits.pop() // discard videos.yml

    return splits.pop().split('.').shift()
  }

  slugify () {
    const file = fs.readFileSync(this.path, 'utf8')
    const document = parseDocument(file)

    const options = {
      indent: 2,
      lineWidth: 180,
      simpleKeys: true,
      singleQuote: false,
      collectionStyle: 'block',
      blockQuote: 'literal',
      defaultKeyType: 'PLAIN',
      defaultStringType: 'QUOTE_DOUBLE',
      directives: true,
      doubleQuotedMinMultiLineLength: 80
    }

    YAML.visit(document, {
      Map: (_, map) => {
        const keys = map.items.map(pair => pair.key.value)
        const hasId = keys.includes('id')
        const hasSlug = keys.includes('slug')

        const eventName = this.eventName(map)
        const title = map.items.find(pair => pair.key.value === 'title')
        const speakersRaw = map.items.find(pair => pair.key.value === 'speakers')
        const speakers = speakersRaw?.value?.items ?? []

        let preEventString = speakers.map(speaker => this.kebabize(speaker.value)).join('-')

        if (eventName === 'GoGaRuCo 2012') {
          console.log('speakers:', preEventString, speakers.length, this.kebabize(title.value.value))
        }

        if (speakers.length === 0 || preEventString === 'todo' || preEventString === 'tbd') {
          preEventString = this.kebabize(title.value.value)
        }

        const videoId = map.items.find(pair => pair.key.value === 'video_id')
        const slug = slugs[videoId.value]

        if (!eventName) {
          console.log(`No event name found for ${videoId.value}`, eventName)
          return
        }

        const eventNameKebab = this.kebabize(eventName)
        const id = (preEventString === eventNameKebab) ? eventNameKebab : `${preEventString}-${eventNameKebab}`

        if (!slug) {
          console.log(`No slug found for ${videoId.value}`)
          return
        }

        if (!hasSlug) {
          map.items.push(
            document.createPair('slug', slug)
          )
        } else {
          map.items.find(pair => pair.key.value === 'slug').value = slug
        }

        if (!hasId) {
          map.items.push(
            document.createPair('id', id)
          )
        } else {
          map.items.find(pair => pair.key.value === 'id').value = id
        }
      }
    })

    fs.writeFileSync(this.path, document.toString(options))
  }
}

const videos = fs.readdirSync('./data', { recursive: true }).filter(file => file.endsWith('videos.yml'))

videos.forEach(video => {
  const addSlug = new AddSlug(`./data/${video}`)
  addSlug.slugify()
})
