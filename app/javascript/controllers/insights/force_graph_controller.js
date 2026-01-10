import { Controller } from '@hotwired/stimulus'
import * as d3 from 'd3'

export default class extends Controller {
  static values = {
    url: String,
    nodeColor: { type: String, default: '#3b82f6' },
    linkColor: { type: String, default: '#94a3b8' }
  }

  static targets = ['search', 'graph', 'results']

  connect () {
    this.fetchData()
  }

  search () {
    const query = this.searchTarget.value.toLowerCase().trim()
    this.highlightNodes(query)
  }

  clearSearch () {
    this.searchTarget.value = ''
    this.highlightNodes('')
  }

  highlightNodes (query) {
    if (!this.nodeSelection || !this.linkSelection) return

    if (!query) {
      this.nodeSelection.attr('opacity', 1).attr('stroke-width', 1.5)
      this.linkSelection.attr('opacity', 0.6)
      if (this.labelSelection) this.labelSelection.attr('opacity', d => (d.talk_count || 0) > 5 ? 1 : 0)
      if (this.hasResultsTarget) this.resultsTarget.innerHTML = ''
      return
    }

    const matches = this.graphData.nodes.filter(n =>
      n.name.toLowerCase().includes(query) ||
      (n.slug && n.slug.toLowerCase().includes(query))
    )

    const matchIds = new Set(matches.map(n => n.id))

    this.nodeSelection
      .attr('opacity', d => matchIds.has(d.id) ? 1 : 0.15)
      .attr('stroke-width', d => matchIds.has(d.id) ? 3 : 1.5)

    this.linkSelection.attr('opacity', d => {
      const sourceId = typeof d.source === 'object' ? d.source.id : d.source
      const targetId = typeof d.target === 'object' ? d.target.id : d.target
      return (matchIds.has(sourceId) || matchIds.has(targetId)) ? 0.6 : 0.05
    })

    if (this.labelSelection) {
      this.labelSelection.attr('opacity', d => matchIds.has(d.id) ? 1 : 0.15)
    }

    if (this.hasResultsTarget) {
      if (matches.length === 0) {
        this.resultsTarget.innerHTML = '<span class="text-warning text-xs">No matches</span>'
      } else if (matches.length <= 5) {
        this.resultsTarget.innerHTML = matches.map(m =>
          `<button type="button" class="btn btn-xs btn-ghost" data-action="click->insights--force-graph#zoomToNode" data-node-id="${m.id}">${m.name}</button>`
        ).join('')
      } else {
        this.resultsTarget.innerHTML = `<span class="text-xs text-base-content/70">${matches.length} matches</span>`
      }
    }
  }

  zoomToNode (event) {
    const nodeId = event.currentTarget.dataset.nodeId
    const node = this.graphData.nodes.find(n => String(n.id) === nodeId)

    if (node && this.zoomBehavior && this.svg) {
      const transform = d3.zoomIdentity
        .translate(this.width / 2, this.height / 2)
        .scale(2)
        .translate(-node.x, -node.y)

      this.svg.transition().duration(750).call(this.zoomBehavior.transform, transform)
    }
  }

  async fetchData () {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()
      this.render(data)
    } catch (error) {
      console.error('Failed to fetch graph data:', error)
      this.element.innerHTML = '<div class="alert alert-error">Failed to load chart data</div>'
    }
  }

  render (data) {
    if (!data || !data.nodes || data.nodes.length === 0) {
      this.element.innerHTML = '<div class="alert alert-warning">No data available</div>'
      return
    }

    this.graphData = data

    const graphContainer = this.hasGraphTarget ? this.graphTarget : this.element
    graphContainer.innerHTML = ''

    this.width = graphContainer.clientWidth
    this.height = graphContainer.clientHeight
    const width = this.width
    const height = this.height

    this.svg = d3.select(graphContainer)
      .append('svg')
      .attr('width', width)
      .attr('height', height)
      .attr('viewBox', [0, 0, width, height])

    const svg = this.svg

    const g = svg.append('g')

    this.zoomBehavior = d3.zoom()
      .scaleExtent([0.1, 4])
      .on('zoom', (event) => {
        g.attr('transform', event.transform)
      })

    svg.call(this.zoomBehavior)

    const nodeById = new Map(data.nodes.map(d => [d.id, d]))

    const links = data.links.map(d => ({
      source: nodeById.get(d.source) || d.source,
      target: nodeById.get(d.target) || d.target,
      value: d.value
    }))

    const nodeDegrees = new Map()
    links.forEach(link => {
      const sourceId = typeof link.source === 'object' ? link.source.id : link.source
      const targetId = typeof link.target === 'object' ? link.target.id : link.target
      nodeDegrees.set(sourceId, (nodeDegrees.get(sourceId) || 0) + 1)
      nodeDegrees.set(targetId, (nodeDegrees.get(targetId) || 0) + 1)
    })

    const linkWidthScale = d3.scaleLinear()
      .domain([d3.min(links, d => d.value), d3.max(links, d => d.value)])
      .range([1, 5])

    const nodeSizeScale = d3.scaleSqrt()
      .domain([0, d3.max(data.nodes, d => d.talk_count || nodeDegrees.get(d.id) || 1)])
      .range([5, 20])

    const simulation = d3.forceSimulation(data.nodes)
      .force('link', d3.forceLink(links).id(d => d.id).distance(80))
      .force('charge', d3.forceManyBody().strength(-150))
      .force('center', d3.forceCenter(width / 2, height / 2))
      .force('collision', d3.forceCollide().radius(d => nodeSizeScale(d.talk_count || nodeDegrees.get(d.id) || 1) + 5))

    const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

    this.linkSelection = g.append('g')
      .selectAll('line')
      .data(links)
      .join('line')
      .attr('stroke', this.linkColorValue)
      .attr('stroke-opacity', 0.6)
      .attr('stroke-width', d => linkWidthScale(d.value))

    const link = this.linkSelection

    this.nodeSelection = g.append('g')
      .selectAll('circle')
      .data(data.nodes)
      .join('circle')
      .attr('r', d => nodeSizeScale(d.talk_count || nodeDegrees.get(d.id) || 1))
      .attr('fill', this.nodeColorValue)
      .attr('stroke', '#fff')
      .attr('stroke-width', 1.5)
      .call(this.drag(simulation))

    const node = this.nodeSelection
      .on('mouseover', (event, d) => {
        tooltip
          .style('opacity', 1)
          .html(`<strong>${d.name}</strong>${d.talk_count ? `<br/>${d.talk_count} talks` : ''}`)
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

    this.labelSelection = g.append('g')
      .selectAll('text')
      .data(data.nodes)
      .join('text')
      .attr('class', 'text-xs fill-current pointer-events-none')
      .attr('dx', d => nodeSizeScale(d.talk_count || nodeDegrees.get(d.id) || 1) + 3)
      .attr('dy', '0.35em')
      .text(d => d.name)
      .style('opacity', d => (d.talk_count || nodeDegrees.get(d.id) || 0) > 5 ? 1 : 0)

    const label = this.labelSelection

    simulation.on('tick', () => {
      link
        .attr('x1', d => d.source.x)
        .attr('y1', d => d.source.y)
        .attr('x2', d => d.target.x)
        .attr('y2', d => d.target.y)

      node
        .attr('cx', d => d.x)
        .attr('cy', d => d.y)

      label
        .attr('x', d => d.x)
        .attr('y', d => d.y)
    })
  }

  drag (simulation) {
    function dragstarted (event) {
      if (!event.active) simulation.alphaTarget(0.3).restart()
      event.subject.fx = event.subject.x
      event.subject.fy = event.subject.y
    }

    function dragged (event) {
      event.subject.fx = event.x
      event.subject.fy = event.y
    }

    function dragended (event) {
      if (!event.active) simulation.alphaTarget(0)
      event.subject.fx = null
      event.subject.fy = null
    }

    return d3.drag()
      .on('start', dragstarted)
      .on('drag', dragged)
      .on('end', dragended)
  }
}
