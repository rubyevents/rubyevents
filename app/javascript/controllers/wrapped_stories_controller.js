import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["page", "progress", "container", "scrollView", "storiesView", "modeLabel", "counter"]
  static values = { index: { type: Number, default: 0 }, mode: { type: String, default: "scroll" } }

  connect() {
    this.updateMode()
    this.handleInitialHash()
    window.addEventListener("hashchange", this.handleHashChange.bind(this))
  }

  disconnect() {
    window.removeEventListener("hashchange", this.handleHashChange.bind(this))
  }

  handleInitialHash() {
    const hash = window.location.hash.slice(1)
    if (hash) {
      const index = this.findPageIndexByName(hash)
      if (index !== -1) {
        this.indexValue = index
        if (this.modeValue === "stories") {
          this.showPage()
        }
      }
    }
  }

  handleHashChange() {
    const hash = window.location.hash.slice(1)
    if (hash) {
      const index = this.findPageIndexByName(hash)
      if (index !== -1 && index !== this.indexValue) {
        this.indexValue = index
        if (this.modeValue === "stories") {
          this.showPage()
        }
      }
    }
  }

  findPageIndexByName(name) {
    return this.pageTargets.findIndex(page => page.dataset.pageName === name)
  }

  updateHash() {
    const currentPage = this.pageTargets[this.indexValue]
    if (currentPage && currentPage.dataset.pageName) {
      const newHash = `#${currentPage.dataset.pageName}`
      if (window.location.hash !== newHash) {
        history.replaceState(null, null, newHash)
      }
    }
  }

  toggleMode() {
    this.modeValue = this.modeValue === "scroll" ? "stories" : "scroll"
    this.updateMode()
  }

  updateMode() {
    if (this.modeValue === "stories") {
      this.scrollViewTarget.classList.add("hidden")
      this.storiesViewTarget.classList.remove("hidden")
      this.modeLabelTarget.textContent = "View as Scroll"
      document.body.style.overflow = "hidden"
      this.showPage()
    } else {
      this.scrollViewTarget.classList.remove("hidden")
      this.storiesViewTarget.classList.add("hidden")
      this.modeLabelTarget.textContent = "View as Stories"
      document.body.style.overflow = ""

      if (window.location.hash) {
        history.replaceState(null, null, window.location.pathname + window.location.search)
      }
    }
  }

  next() {
    if (this.indexValue < this.pageTargets.length - 1) {
      this.indexValue++
      this.showPage()
    }
  }

  previous() {
    if (this.indexValue > 0) {
      this.indexValue--
      this.showPage()
    }
  }

  goToPage(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (!isNaN(index)) {
      this.indexValue = index
      this.showPage()
    }
  }

  handleClick(event) {
    if (event.target.closest('button, a, [data-action]')) return

    const rect = this.containerTarget.getBoundingClientRect()
    const clickX = event.clientX - rect.left
    const width = rect.width

    if (clickX < width / 3) {
      this.previous()
    } else {
      this.next()
    }
  }

  handleKeydown(event) {
    if (this.modeValue !== "stories") return

    if (event.key === "ArrowRight" || event.key === " ") {
      event.preventDefault()
      this.next()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.previous()
    } else if (event.key === "Escape") {
      this.toggleMode()
    }
  }

  showPage() {
    this.pageTargets.forEach((page, index) => {
      if (index === this.indexValue) {
        page.classList.add("active")
      } else {
        page.classList.remove("active")
      }
    })

    this.progressTargets.forEach((bar, index) => {
      if (index <= this.indexValue) {
        bar.classList.add("active")
      } else {
        bar.classList.remove("active")
      }
    })

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.indexValue + 1} / ${this.pageTargets.length}`
    }

    this.updateHash()
  }
}
