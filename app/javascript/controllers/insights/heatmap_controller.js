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
      console.error('Failed to fetch heatmap data:', error)
      this.element.innerHTML = '<div class="alert alert-error">Failed to load chart data</div>'
    }
  }

  render (data) {
    if (!data || data.length === 0) {
      this.element.innerHTML = '<div class="alert alert-warning">No data available</div>'
      return
    }

    this.element.innerHTML = ''

    const margin = { top: 30, right: 30, bottom: 40, left: 60 }
    const width = this.element.clientWidth - margin.left - margin.right
    const height = this.element.clientHeight - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`)

    const years = [...new Set(data.map(d => d.year))].sort()
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

    const x = d3.scaleBand()
      .domain(months)
      .range([0, width])
      .padding(0.05)

    const y = d3.scaleBand()
      .domain(years)
      .range([0, height])
      .padding(0.05)

    const maxCount = d3.max(data, d => d.count)
    const color = d3.scaleSequential()
      .domain([0, maxCount])
      .interpolator(d3.interpolateBlues)

    svg.append('g')
      .attr('transform', `translate(0,${height})`)
      .call(d3.axisBottom(x))
      .selectAll('text')
      .attr('class', 'text-xs')

    svg.append('g')
      .call(d3.axisLeft(y))
      .selectAll('text')
      .attr('class', 'text-xs')

    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    svg.selectAll('rect')
      .data(data)
      .join('rect')
      .attr('x', d => x(months[d.month - 1]))
      .attr('y', d => y(d.year))
      .attr('width', x.bandwidth())
      .attr('height', y.bandwidth())
      .attr('fill', d => d.count > 0 ? color(d.count) : '#f3f4f6')
      .attr('rx', 2)
      .on('mouseover', (event, d) => {
        tooltip
          .style('opacity', 1)
          .html(`<strong>${months[d.month - 1]} ${d.year}</strong><br/>${d.count} events`)
      })
      .on('mousemove', (event) => {
        tooltip
          .style('left', (event.offsetX + 10) + 'px')
          .style('top', (event.offsetY - 10) + 'px')
      })
      .on('mouseout', () => {
        tooltip.style('opacity', 0)
      })
  }
}
