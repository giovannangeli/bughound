import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("✅ Navbar controller connected")
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener('scroll', this.handleScroll, { passive: true })
  }
  
  disconnect() {
    window.removeEventListener('scroll', this.handleScroll)
  }
  
  handleScroll() {
    if (window.scrollY > 50) {
      this.element.classList.add('scrolled')
    } else {
      this.element.classList.remove('scrolled')
    }
  }
}