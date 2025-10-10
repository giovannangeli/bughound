import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "leftArrow", "rightArrow"]
  
  connect() {
    console.log("✅ Carousel controller connected")
    this.updateArrows()
  }
  
  scrollLeft() {
    const step = this.getStep()
    this.trackTarget.scrollBy({ left: -step, behavior: 'smooth' })
  }
  
  scrollRight() {
    const step = this.getStep()
    this.trackTarget.scrollBy({ left: step, behavior: 'smooth' })
  }
  
  updateArrows() {
    if (!this.hasLeftArrowTarget || !this.hasRightArrowTarget) return
    
    const maxScroll = this.trackTarget.scrollWidth - this.trackTarget.clientWidth - 1
    
    this.leftArrowTarget.classList.toggle('is-disabled', this.trackTarget.scrollLeft <= 0)
    this.rightArrowTarget.classList.toggle('is-disabled', this.trackTarget.scrollLeft >= maxScroll)
  }
  
  getStep() {
    const card = this.trackTarget.querySelector('.mode-card')
    if (!card) return 0
    
    const styles = getComputedStyle(this.trackTarget)
    const gap = parseFloat(styles.columnGap || styles.gap) || 24
    
    return card.getBoundingClientRect().width + gap
  }
  
  disconnect() {
    console.log("🧹 Carousel disconnected")
  }
}