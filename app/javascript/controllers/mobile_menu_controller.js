import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]
  
  connect() {
    console.log("✅ Mobile menu controller connected")
    this.boundClose = this.closeOnOutsideClick.bind(this)
  }
  
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (!this.hasMenuTarget) return
    
    const isOpen = this.menuTarget.classList.toggle('mobile-menu-open')
    
    if (isOpen) {
      // Ajoute le listener SEULEMENT si ouvert
      setTimeout(() => {
        document.addEventListener('click', this.boundClose)
      }, 0)
    } else {
      document.removeEventListener('click', this.boundClose)
    }
  }
  
  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove('mobile-menu-open')
      document.removeEventListener('click', this.boundClose)
    }
  }
  
  closeOnLink() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove('mobile-menu-open')
      document.removeEventListener('click', this.boundClose)
    }
  }
  
  disconnect() {
    document.removeEventListener('click', this.boundClose)
  }
}