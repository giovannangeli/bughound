import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]
  
  connect() {
    console.log("✅ User menu controller connected")
  }
  
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const isOpen = this.menuTarget.classList.toggle("show")
    this.buttonTarget.setAttribute("aria-expanded", isOpen)
  }
  
  close(event) {
    // Ferme si clic en dehors
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("show")
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }
  
  closeOnEscape(event) {
    if (event.key === "Escape" && this.menuTarget.classList.contains("show")) {
      this.menuTarget.classList.remove("show")
      this.buttonTarget.setAttribute("aria-expanded", "false")
      this.buttonTarget.focus()
    }
  }
}