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
      console.error('Failed to fetch stacked area data:', error)
      this.element.innerHTML = '<div class="alert alert-error">Failed to load chart data</div>'
    }
  }

  render (data) {
    if (!data || data.length === 0) {
      this.element.innerHTML = '<div class="alert alert-warning">No data available</div>'
      return
    }

    this.element.innerHTML = ''

    const margin = { top: 20, right: 150, bottom: 40, left: 50 }
    const width = this.element.clientWidth - margin.left - margin.right
    const height = this.element.clientHeight - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`)

    const keys = Object.keys(data[0]).filter(k => k !== 'year')

    const color = d3.scaleOrdinal()
      .domain(keys)
      .range(d3.schemeTableau10)

    const stack = d3.stack()
      .keys(keys)
      .order(d3.stackOrderNone)
      .offset(d3.stackOffsetNone)

    const stackedData = stack(data)

    const x = d3.scalePoint()
      .domain(data.map(d => d.year))
      .range([0, width])

    const y = d3.scaleLinear()
      .domain([0, d3.max(stackedData, layer => d3.max(layer, d => d[1]))])
      .nice()
      .range([height, 0])

    const area = d3.area()
      .x(d => x(d.data.year))
      .y0(d => y(d[0]))
      .y1(d => y(d[1]))
      .curve(d3.curveMonotoneX)

    svg.append('g')
      .attr('transform', `translate(0,${height})`)
      .call(d3.axisBottom(x).tickValues(x.domain().filter((d, i) => i % 2 === 0)))
      .selectAll('text')
      .attr('transform', 'rotate(-45)')
      .style('text-anchor', 'end')

    svg.append('g')
      .call(d3.axisLeft(y))

    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    svg.selectAll('.area')
      .data(stackedData)
      .join('path')
      .attr('class', 'area')
      .attr('fill', d => color(d.key))
      .attr('fill-opacity', 0.7)
      .attr('stroke', d => color(d.key))
      .attr('stroke-width', 1)
      .attr('d', area)
      .on('mouseover', (event, d) => {
        tooltip
          .style('opacity', 1)
          .html(`<strong>${d.key}</strong>`)
      })
      .on('mousemove', (event) => {
        tooltip
          .style('left', (event.offsetX + 10) + 'px')
          .style('top', (event.offsetY - 10) + 'px')
      })
      .on('mouseout', () => {
        tooltip.style('opacity', 0)
      })

    const legend = svg.append('g')
      .attr('transform', `translate(${width + 10}, 0)`)

    keys.slice(0, 10).forEach((key, i) => {
      const g = legend.append('g')
        .attr('transform', `translate(0, ${i * 18})`)

      g.append('rect')
        .attr('width', 12)
        .attr('height', 12)
        .attr('fill', color(key))
        .attr('fill-opacity', 0.7)

      g.append('text')
        .attr('x', 18)
        .attr('y', 10)
        .attr('class', 'text-xs fill-current')
        .text(this.truncate(key, 15))
    })
  }

  truncate (str, maxLength) {
    if (str.length <= maxLength) return str
    return str.substring(0, maxLength - 3) + '...'
  }
}
