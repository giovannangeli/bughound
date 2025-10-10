import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  
  connect() {
    console.log("✅ Dropdown controller connected")
  }
  
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    event.stopImmediatePropagation()
    
    const isOpen = this.menuTarget.classList.contains('show')
    
    // Fermer TOUS les autres dropdowns
    document.querySelectorAll('[data-controller="dropdown"]').forEach(el => {
      if (el !== this.element) {
        const menu = el.querySelector('[data-dropdown-target="menu"]')
        if (menu) {
          menu.classList.remove('show', 'open')
        }
        el.classList.remove('open')
      }
    })
    
    // Toggle SEULEMENT celui-ci
    if (!isOpen) {
      this.menuTarget.classList.add('show', 'open')
      this.element.classList.add('open')
      
      // Fermer au clic extérieur SEULEMENT
      this.boundClose = (e) => {
        // NE PAS fermer si clic sur un bouton modal
        if (e.target.closest('[data-action*="modal"]')) {
          return // Laisse le modal gérer le clic
        }
        
        // Fermer si clic en dehors du dropdown
        if (!this.element.contains(e.target)) {
          this.close()
          document.removeEventListener('click', this.boundClose)
        }
      }
      
      setTimeout(() => {
        document.addEventListener('click', this.boundClose)
      }, 0)
    } else {
      this.close()
    }
  }
  
  close() {
    this.menuTarget.classList.remove('show', 'open')
    this.element.classList.remove('open')
    if (this.boundClose) {
      document.removeEventListener('click', this.boundClose)
    }
  }
  
  disconnect() {
    this.close()
  }
}