import { Controller } from '@hotwired/stimulus'
import * as d3 from 'd3'

export default class extends Controller {
  static values = {
    url: String
  }

  connect () {
    this.fetchData()
  }

  async fetchData () {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()
      this.render(data)
    } catch (error) {
      console.error('Failed to fetch word cloud data:', error)
      this.element.innerHTML = '<div class="alert alert-error">Failed to load chart data</div>'
    }
  }

  render (data) {
    if (!data || data.length === 0) {
      this.element.innerHTML = '<div class="alert alert-warning">No data available</div>'
      return
    }

    this.element.innerHTML = ''

    const width = this.element.clientWidth
    const height = this.element.clientHeight

    const maxValue = d3.max(data, d => d.value)
    const minValue = d3.min(data, d => d.value)
    const fontScale = d3.scaleLog()
      .domain([minValue, maxValue])
      .range([12, 48])

    const colors = ['#dc2626', '#ea580c', '#16a34a', '#2563eb', '#7c3aed', '#db2777', '#0891b2', '#4f46e5']
    const colorScale = d3.scaleOrdinal(colors)

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width)
      .attr('height', height)

    const g = svg.append('g')
      .attr('transform', `translate(${width / 2},${height / 2})`)

    const words = data.slice(0, 80)

    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    words.forEach((word, i) => {
      const fontSize = fontScale(word.value)
      const angle = i * 0.5
      const radius = 10 + i * 3

      const x = Math.cos(angle) * radius
      const y = Math.sin(angle) * radius

      g.append('text')
        .attr('class', 'cursor-pointer')
        .attr('text-anchor', 'middle')
        .attr('x', x)
        .attr('y', y)
        .attr('font-size', fontSize)
        .attr('fill', colorScale(i % colors.length))
        .text(word.text)
        .on('mouseover', () => {
          tooltip
            .style('opacity', 1)
            .html(`<strong>${word.text}</strong><br/>${word.value} occurrences`)
        })
        .on('mousemove', (event) => {
          const rect = this.element.getBoundingClientRect()
          tooltip
            .style('left', (event.clientX - rect.left + 10) + 'px')
            .style('top', (event.clientY - rect.top - 10) + 'px')
        })
        .on('mouseout', () => {
          tooltip.style('opacity', 0)
        })
    })
  }
}
