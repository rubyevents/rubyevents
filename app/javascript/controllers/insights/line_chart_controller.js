import { Controller } from '@hotwired/stimulus'
import * as d3 from 'd3'

export default class extends Controller {
  static values = {
    url: String,
    xKey: { type: String, default: 'year' },
    yKey: { type: String, default: 'count' },
    y2Key: { type: String, default: '' }
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
      console.error('Failed to fetch line chart data:', error)
      this.element.innerHTML = '<div class="alert alert-error">Failed to load chart data</div>'
    }
  }

  render (data) {
    if (!data || data.length === 0) {
      this.element.innerHTML = '<div class="alert alert-warning">No data available</div>'
      return
    }

    this.element.innerHTML = ''

    const margin = { top: 20, right: 60, bottom: 40, left: 50 }
    const width = this.element.clientWidth - margin.left - margin.right
    const height = this.element.clientHeight - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append('svg')
      .attr('width', width + margin.left + margin.right)
      .attr('height', height + margin.top + margin.bottom)
      .append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`)

    const xKey = this.xKeyValue
    const yKey = this.yKeyValue
    const y2Key = this.y2KeyValue

    const x = d3.scalePoint()
      .domain(data.map(d => d[xKey]))
      .range([0, width])

    const y = d3.scaleLinear()
      .domain([0, d3.max(data, d => Math.max(d[yKey], y2Key ? d[y2Key] : 0))])
      .nice()
      .range([height, 0])

    const line = d3.line()
      .x(d => x(d[xKey]))
      .y(d => y(d[yKey]))
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

    svg.append('path')
      .datum(data)
      .attr('fill', 'none')
      .attr('stroke', '#3b82f6')
      .attr('stroke-width', 2)
      .attr('d', line)

    if (y2Key) {
      const line2 = d3.line()
        .x(d => x(d[xKey]))
        .y(d => y(d[y2Key]))
        .curve(d3.curveMonotoneX)

      svg.append('path')
        .datum(data)
        .attr('fill', 'none')
        .attr('stroke', '#10b981')
        .attr('stroke-width', 2)
        .attr('stroke-dasharray', '5,5')
        .attr('d', line2)
    }

    svg.selectAll('circle')
      .data(data)
      .join('circle')
      .attr('cx', d => x(d[xKey]))
      .attr('cy', d => y(d[yKey]))
      .attr('r', 4)
      .attr('fill', '#3b82f6')
      .on('mouseover', (event, d) => {
        let html = `<strong>${d[xKey]}</strong><br/>${yKey}: ${d[yKey]}`
        if (y2Key) html += `<br/>${y2Key}: ${d[y2Key]}`
        tooltip.style('opacity', 1).html(html)
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
