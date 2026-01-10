import { Controller } from '@hotwired/stimulus'
import * as d3 from 'd3'

export default class extends Controller {
  static values = {
    url: String,
    labelKey: { type: String, default: 'name' },
    valueKey: { type: String, default: 'talk_count' },
    limit: { type: Number, default: 20 }
  }

  connect () {
    this.fetchData()
  }

  async fetchData () {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()
      this.render(data.slice(0, this.limitValue))
    } catch (error) {
      console.error('Failed to fetch bar chart data:', error)
      this.element.innerHTML = '<div class="alert alert-error">Failed to load chart data</div>'
    }
  }

  render (data) {
    if (!data || data.length === 0) {
      this.element.innerHTML = '<div class="alert alert-warning">No data available</div>'
      return
    }

    this.element.innerHTML = ''

    const margin = { top: 10, right: 30, bottom: 10, left: 150 }
    const width = this.element.clientWidth - margin.left - margin.right
    const height = this.element.clientHeight - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`)

    const labelKey = this.labelKeyValue
    const valueKey = this.valueKeyValue

    const x = d3.scaleLinear()
      .domain([0, d3.max(data, d => d[valueKey])])
      .range([0, width])

    const y = d3.scaleBand()
      .domain(data.map(d => d[labelKey]))
      .range([0, height])
      .padding(0.2)

    const color = d3.scaleSequential()
      .domain([0, d3.max(data, d => d[valueKey])])
      .interpolator(d3.interpolateBlues)

    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    svg.selectAll('rect')
      .data(data)
      .join('rect')
      .attr('x', 0)
      .attr('y', d => y(d[labelKey]))
      .attr('width', d => x(d[valueKey]))
      .attr('height', y.bandwidth())
      .attr('fill', d => color(d[valueKey]))
      .attr('rx', 4)
      .on('mouseover', (event, d) => {
        tooltip
          .style('opacity', 1)
          .html(`<strong>${d[labelKey]}</strong><br/>${d[valueKey]} talks`)
      })
      .on('mousemove', (event) => {
        tooltip
          .style('left', (event.offsetX + 10) + 'px')
          .style('top', (event.offsetY - 10) + 'px')
      })
      .on('mouseout', () => {
        tooltip.style('opacity', 0)
      })

    svg.selectAll('.label')
      .data(data)
      .join('text')
      .attr('class', 'label text-xs fill-current')
      .attr('x', -5)
      .attr('y', d => y(d[labelKey]) + y.bandwidth() / 2)
      .attr('dy', '0.35em')
      .attr('text-anchor', 'end')
      .text(d => this.truncate(d[labelKey], 20))

    svg.selectAll('.value')
      .data(data)
      .join('text')
      .attr('class', 'value text-xs font-medium')
      .attr('x', d => x(d[valueKey]) + 5)
      .attr('y', d => y(d[labelKey]) + y.bandwidth() / 2)
      .attr('dy', '0.35em')
      .attr('fill', 'currentColor')
      .text(d => d[valueKey])
  }

  truncate (str, maxLength) {
    if (str.length <= maxLength) return str

    return str.substring(0, maxLength - 3) + '...'
  }
}
