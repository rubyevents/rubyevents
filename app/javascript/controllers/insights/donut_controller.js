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
      console.error('Failed to fetch donut data:', error)
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
    const radius = Math.min(width, height) / 2 - 40

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width)
      .attr('height', height)
      .append('g')
      .attr('transform', `translate(${width / 2},${height / 2})`)

    const color = d3.scaleOrdinal()
      .domain(data.map(d => d.kind))
      .range(d3.schemeTableau10)

    const pie = d3.pie()
      .value(d => d.count)
      .sort(null)

    const arc = d3.arc()
      .innerRadius(radius * 0.5)
      .outerRadius(radius)

    const labelArc = d3.arc()
      .innerRadius(radius * 0.8)
      .outerRadius(radius * 0.8)

    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    const arcs = svg.selectAll('.arc')
      .data(pie(data))
      .join('g')
      .attr('class', 'arc')

    arcs.append('path')
      .attr('d', arc)
      .attr('fill', d => color(d.data.kind))
      .attr('stroke', 'white')
      .attr('stroke-width', 2)
      .on('mouseover', (event, d) => {
        tooltip
          .style('opacity', 1)
          .html(`<strong>${d.data.label}</strong><br/>${d.data.count} events`)
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

    arcs.filter(d => (d.endAngle - d.startAngle) > 0.3)
      .append('text')
      .attr('transform', d => `translate(${labelArc.centroid(d)})`)
      .attr('text-anchor', 'middle')
      .attr('class', 'text-xs font-medium fill-white')
      .text(d => d.data.label)

    svg.append('text')
      .attr('text-anchor', 'middle')
      .attr('dy', '-0.2em')
      .attr('class', 'text-2xl font-bold fill-current')
      .text(d3.sum(data, d => d.count))

    svg.append('text')
      .attr('text-anchor', 'middle')
      .attr('dy', '1.2em')
      .attr('class', 'text-sm fill-current opacity-70')
      .text('Total Events')
  }
}
