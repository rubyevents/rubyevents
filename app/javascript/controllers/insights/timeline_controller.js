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
      console.error('Failed to fetch timeline data:', error)
      this.element.innerHTML = '<div class="alert alert-error">Failed to load chart data</div>'
    }
  }

  render (data) {
    if (!data || data.length === 0) {
      this.element.innerHTML = '<div class="alert alert-warning">No data available</div>'
      return
    }

    this.element.innerHTML = ''

    const margin = { top: 20, right: 120, bottom: 40, left: 50 }
    const width = this.element.clientWidth - margin.left - margin.right
    const height = this.element.clientHeight - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`)

    // Get all kinds (excluding 'year')
    const kinds = Object.keys(data[0]).filter(k => k !== 'year')

    // Color scale
    const color = d3.scaleOrdinal()
      .domain(kinds)
      .range(d3.schemeTableau10)

    // Stack the data
    const stack = d3.stack()
      .keys(kinds)
      .order(d3.stackOrderNone)
      .offset(d3.stackOffsetNone)

    const stackedData = stack(data)

    // Scales
    const x = d3.scaleBand()
      .domain(data.map(d => d.year))
      .range([0, width])
      .padding(0.1)

    const y = d3.scaleLinear()
      .domain([0, d3.max(stackedData, layer => d3.max(layer, d => d[1]))])
      .nice()
      .range([height, 0])

    // Add X axis
    svg.append('g')
      .attr('transform', `translate(0,${height})`)
      .call(d3.axisBottom(x).tickValues(x.domain().filter((d, i) => i % 2 === 0)))
      .selectAll('text')
      .attr('transform', 'rotate(-45)')
      .style('text-anchor', 'end')

    // Add Y axis
    svg.append('g')
      .call(d3.axisLeft(y))

    // Tooltip
    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    // Add stacked bars
    svg.append('g')
      .selectAll('g')
      .data(stackedData)
      .join('g')
      .attr('fill', d => color(d.key))
      .selectAll('rect')
      .data(d => d.map(item => ({ ...item, key: d.key })))
      .join('rect')
      .attr('x', d => x(d.data.year))
      .attr('y', d => y(d[1]))
      .attr('height', d => y(d[0]) - y(d[1]))
      .attr('width', x.bandwidth())
      .on('mouseover', (event, d) => {
        tooltip
          .style('opacity', 1)
          .html(`<strong>${d.data.year}</strong><br/>${d.key}: ${d[1] - d[0]}`)
      })
      .on('mousemove', (event) => {
        tooltip
          .style('left', (event.offsetX + 10) + 'px')
          .style('top', (event.offsetY - 10) + 'px')
      })
      .on('mouseout', () => {
        tooltip.style('opacity', 0)
      })

    // Legend
    const legend = svg.append('g')
      .attr('transform', `translate(${width + 10}, 0)`)

    kinds.forEach((kind, i) => {
      const g = legend.append('g')
        .attr('transform', `translate(0, ${i * 20})`)

      g.append('rect')
        .attr('width', 15)
        .attr('height', 15)
        .attr('fill', color(kind))

      g.append('text')
        .attr('x', 20)
        .attr('y', 12)
        .attr('class', 'text-xs fill-current')
        .text(kind.replace('_', ' '))
    })
  }
}
