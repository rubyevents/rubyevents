import { Controller } from '@hotwired/stimulus'
import * as d3 from 'd3'

export default class extends Controller {
  static values = {
    url: String
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
      this.nodeSelection
        .attr('opacity', 1)
        .attr('stroke-width', 1.5)

      this.linkSelection
        .attr('opacity', d => Math.min(d.value / 5, 0.6))

      if (this.labelSelection) {
        this.labelSelection.attr('opacity', 1)
      }

      if (this.hasResultsTarget) {
        this.resultsTarget.innerHTML = ''
      }
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

    this.linkSelection
      .attr('opacity', d => {
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
          `<button type="button" class="btn btn-xs btn-ghost" data-action="click->insights--cluster-graph#zoomToNode" data-node-id="${m.id}">${m.name}</button>`
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

      this.svg.transition()
        .duration(750)
        .call(this.zoomBehavior.transform, transform)
    }
  }

  async fetchData () {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()
      this.render(data)
    } catch (error) {
      console.error('Failed to fetch cluster graph data:', error)
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

    const clusterColors = d3.scaleOrdinal(d3.schemeTableau10)

    this.svg = d3.select(graphContainer)
      .append('svg')
      .attr('width', width)
      .attr('height', height)

    const svg = this.svg
    const g = svg.append('g')

    this.zoomBehavior = d3.zoom()
      .scaleExtent([0.1, 4])
      .on('zoom', (event) => {
        g.attr('transform', event.transform)
      })

    svg.call(this.zoomBehavior)

        const tooltip = d3.select(this.element)
      .append('div')
      .attr('class', 'tooltip bg-base-300 px-3 py-2 rounded-lg shadow-lg text-sm absolute pointer-events-none opacity-0')
      .style('z-index', '100')

        const nodeById = new Map(data.nodes.map(d => [d.id, d]))

        const links = data.links.map(d => ({
      source: nodeById.get(d.source),
      target: nodeById.get(d.target),
      value: d.value,
      sharedTopics: d.shared_topics
    })).filter(d => d.source && d.target)

        const clusterFields = [
      'cluster', 'pattern', 'circuit', 'generation', 'duration_type', 'evolution_type', 'style', 'primary_region',
      'attendance_type', 'viewer_type', 'travel_style', 'talk_style', 'timing_style', 'loyalty_type', 'role', 'evolution'
    ]
    const clusterField = clusterFields.find(f => data.nodes[0] && data.nodes[0][f] !== undefined) || 'cluster'

        const clusterCenters = {}
    const clusterCounts = {}
    data.nodes.forEach(n => {
      const clusterKey = n[clusterField] || 'unknown'
      clusterCounts[clusterKey] = (clusterCounts[clusterKey] || 0) + 1
    })

        const numClusters = Object.keys(clusterCounts).length
    Object.keys(clusterCounts).forEach((cluster, i) => {
      const angle = (2 * Math.PI * i) / numClusters
      const radius = Math.min(width, height) * 0.35
      clusterCenters[cluster] = {
        x: width / 2 + Math.cos(angle) * radius,
        y: height / 2 + Math.sin(angle) * radius
      }
    })

        function clusterForce (alpha) {
      data.nodes.forEach(d => {
        const clusterKey = d[clusterField] || 'unknown'
        const center = clusterCenters[clusterKey]
        if (center) {
          d.vx -= (d.x - center.x) * alpha * 0.05
          d.vy -= (d.y - center.y) * alpha * 0.05
        }
      })
    }

        const simulation = d3.forceSimulation(data.nodes)
      .force('link', d3.forceLink(links)
        .id(d => d.id)
        .distance(d => 80 - d.value * 5)
        .strength(d => 0.3 + d.value / 30))
      .force('charge', d3.forceManyBody().strength(-60))
      .force('center', d3.forceCenter(width / 2, height / 2).strength(0.03))
      .force('collision', d3.forceCollide().radius(25))
      .force('cluster', clusterForce)
    this.linkSelection = g.append('g')
      .selectAll('line')
      .data(links)
      .join('line')
      .attr('stroke', '#999')
      .attr('stroke-opacity', d => Math.min(d.value / 5, 0.6))
      .attr('stroke-width', d => Math.max(d.value / 3, 0.5))

    const link = this.linkSelection
    const sizeFields = ['topic_count', 'talk_count', 'total_talks', 'pioneer_count', 'country_count', 'unique_collaborators']
    const sizeField = sizeFields.find(f => data.nodes[0] && data.nodes[0][f] !== undefined)
    this.nodeSelection = g.append('g')
      .selectAll('circle')
      .data(data.nodes)
      .join('circle')
      .attr('r', d => {
        const size = sizeField ? (d[sizeField] || 1) : 5
        return 4 + Math.sqrt(size) * 2
      })
      .attr('fill', d => clusterColors(d[clusterField] || 'unknown'))
      .attr('stroke', '#fff')
      .attr('stroke-width', 1.5)
      .call(this.drag(simulation))

    const node = this.nodeSelection
      .on('mouseover', (event, d) => {
        const clusterValue = d[clusterField] || 'Unknown'
        const details = []
        if (d.topics) details.push(`Topics: ${d.topics.join(', ')}`)
        if (d.top_topics) details.push(`Topics: ${d.top_topics.join(', ')}`)
        if (d.trajectory) details.push(`Path: ${d.trajectory.join(' → ')}`)
        if (d.pioneered_events) details.push(`Pioneered: ${d.pioneered_events.join(', ')}`)
        if (d.mentored && d.mentored.length > 0) details.push(`Mentored: ${d.mentored.join(', ')}`)
        if (d.talk_count) details.push(`${d.talk_count} talks`)
        if (d.total_talks) details.push(`${d.total_talks} talks`)
        if (d.avg_duration) details.push(`Avg: ${d.avg_duration} min`)
        if (d.avg_title_words) details.push(`Avg ${d.avg_title_words} words/title`)
        if (d.solo_ratio !== undefined) details.push(`${d.solo_ratio}% solo`)
        if (d.country_count) details.push(`${d.country_count} countries`)
        if (d.primary_country) details.push(`Primary: ${d.primary_country}`)
        if (d.event_count) details.push(`${d.event_count} events`)
        if (d.unique_series) details.push(`${d.unique_series} series`)
        if (d.career_span) details.push(`${d.career_span} year career`)
        if (d.debut_year) details.push(`Debut: ${d.debut_year}`)
        if (d.early_ratio !== undefined) details.push(`${d.early_ratio}% early adopter`)
        if (d.recycling_ratio !== undefined) details.push(`${d.recycling_ratio}% similar talks`)
        if (d.concentration) details.push(`${d.concentration}% in season`)
        if (d.loyalty_score) details.push(`${d.loyalty_score}% loyalty`)
        if (d.mentored_count) details.push(`Mentored ${d.mentored_count} speakers`)
        if (d.word_count_change) details.push(`Title change: ${d.word_count_change > 0 ? '+' : ''}${d.word_count_change} words`)

        tooltip
          .style('opacity', 1)
          .html(`
            <strong>${d.name}</strong><br/>
            <span class="text-xs font-medium" style="color: ${clusterColors(clusterValue)}">${clusterValue}</span><br/>
            <span class="text-xs text-gray-400">${details.slice(0, 3).join('<br/>')}</span>
          `)
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
      .data(data.nodes.filter(d => {
        const size = sizeField ? (d[sizeField] || 0) : 0
        return size >= 5
      }))
      .join('text')
      .attr('class', 'text-xs fill-current pointer-events-none')
      .attr('dx', 8)
      .attr('dy', 3)
      .text(d => d.name)

    const labels = this.labelSelection
    simulation.on('tick', () => {
      link
        .attr('x1', d => d.source.x)
        .attr('y1', d => d.source.y)
        .attr('x2', d => d.target.x)
        .attr('y2', d => d.target.y)

      node
        .attr('cx', d => d.x)
        .attr('cy', d => d.y)

      labels
        .attr('x', d => d.x)
        .attr('y', d => d.y)
    })
    let legendY = 20
    if (data.cluster_count) {
      svg.append('text')
        .attr('x', 10)
        .attr('y', legendY)
        .attr('class', 'text-xs fill-current')
        .text(`${data.nodes.length} speakers in ${data.cluster_count} clusters`)
      legendY += 16
    }

    if (data.excluded_topics && data.excluded_topics.length > 0) {
      svg.append('text')
        .attr('x', 10)
        .attr('y', legendY)
        .attr('class', 'text-xs fill-current opacity-60')
        .text(`Excluded common topics: ${data.excluded_topics.join(', ')}`)
    }
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
