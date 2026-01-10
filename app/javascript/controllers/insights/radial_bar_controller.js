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
      console.error('Failed to fetch radial data:', error)
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
    const innerRadius = 60
    const outerRadius = Math.min(width, height) / 2 - 30

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width)
      .attr('height', height)
      .append('g')
      .attr('transform', `translate(${width / 2},${height / 2})`)

    const maxCount = d3.max(data, d => d.count)
    const y = d3.scaleRadial()
      .domain([0, maxCount])
      .range([innerRadius, outerRadius])

    const x = d3.scaleBand()
      .domain(data.map(d => d.name))
      .range([0, 2 * Math.PI])
      .padding(0.1)

    const color = d3.scaleSequential()
      .domain([0, maxCount])
      .interpolator(d3.interpolateBlues)

    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    svg.append('g')
      .selectAll('path')
      .data(data)
      .join('path')
      .attr('fill', d => color(d.count))
      .attr('d', d3.arc()
        .innerRadius(innerRadius)
        .outerRadius(d => y(d.count))
        .startAngle(d => x(d.name))
        .endAngle(d => x(d.name) + x.bandwidth())
        .padAngle(0.02)
        .padRadius(innerRadius))
      .on('mouseover', (event, d) => {
        tooltip
          .style('opacity', 1)
          .html(`<strong>${d.name}</strong><br/>${d.count} events`)
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

    svg.append('g')
      .selectAll('g')
      .data(data)
      .join('g')
      .attr('text-anchor', d => (x(d.name) + x.bandwidth() / 2 + Math.PI) % (2 * Math.PI) < Math.PI ? 'end' : 'start')
      .attr('transform', d => `rotate(${(x(d.name) + x.bandwidth() / 2) * 180 / Math.PI - 90}) translate(${outerRadius + 10},0)`)
      .append('text')
      .attr('transform', d => (x(d.name) + x.bandwidth() / 2 + Math.PI) % (2 * Math.PI) < Math.PI ? 'rotate(180)' : 'rotate(0)')
      .attr('class', 'text-xs fill-current')
      .text(d => d.name)

    svg.append('text')
      .attr('text-anchor', 'middle')
      .attr('dy', '0.35em')
      .attr('class', 'text-lg font-bold fill-current')
      .text(d3.sum(data, d => d.count))
  }
}
