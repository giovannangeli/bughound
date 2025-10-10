import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]
  static values = {
    analysisId: Number,
    analysisTitle: String,
    analysisUrl: String
  }
  
  connect() {
    console.log("✅ Modal controller connected")
  }
  
  // Ouvrir le modal de partage
  openShare(event) {
    const analysisId = event.currentTarget.dataset.analysisId
    const analysisTitle = event.currentTarget.dataset.analysisTitle
    const analysisUrl = event.currentTarget.dataset.analysisUrl
    
    this.analysisIdValue = analysisId
    this.analysisTitleValue = analysisTitle
    this.analysisUrlValue = analysisUrl
    
    document.getElementById('shareModalTitle').textContent = `Analyse: "${analysisTitle}"`
    document.getElementById('shareModal').classList.add('active')
  }
  
  closeShare() {
    document.getElementById('shareModal').classList.remove('active')
    this.analysisUrlValue = null
  }
  
  // Ouvrir le modal de suppression
  openDelete(event) {
    const analysisId = event.currentTarget.dataset.analysisId
    const analysisTitle = event.currentTarget.dataset.analysisTitle
    
    this.analysisIdValue = analysisId
    
    document.getElementById('deleteModalTitle').textContent = `Analyse: "${analysisTitle}"`
    document.getElementById('deleteModal').classList.add('active')
  }
  
  closeDelete() {
    document.getElementById('deleteModal').classList.remove('active')
    this.analysisIdValue = null
  }
  
  confirmDelete() {
    if (!this.analysisIdValue) return
    
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/analyses/${this.analysisIdValue}`
    form.style.display = 'none'
    
    // Token CSRF
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)
    
    // Méthode DELETE
    const methodInput = document.createElement('input')
    methodInput.type = 'hidden'
    methodInput.name = '_method'
    methodInput.value = 'delete'
    form.appendChild(methodInput)
    
    document.body.appendChild(form)
    form.submit()
  }
  
  // Copier l'URL
  copyUrl() {
    if (!this.analysisUrlValue) return
    
    const button = document.querySelector('.share-btn-primary')
    const originalHTML = button.innerHTML
    
    navigator.clipboard.writeText(this.analysisUrlValue).then(() => {
      button.innerHTML = '<i class="fas fa-check"></i><span>Lien copié !</span>'
      button.style.background = '#059669'
      button.style.transform = 'scale(1.05)'
      
      setTimeout(() => {
        button.innerHTML = originalHTML
        button.style.background = '#10b981'
        button.style.transform = 'scale(1)'
      }, 2000)
    }).catch(() => {
      button.innerHTML = '<i class="fas fa-exclamation-triangle"></i><span>Erreur copie</span>'
      button.style.background = '#f59e0b'
      
      setTimeout(() => {
        prompt('Copiez ce lien :', this.analysisUrlValue)
        button.innerHTML = originalHTML
        button.style.background = '#10b981'
      }, 1000)
    })
  }
  
  // Télécharger PDF
  downloadPdf() {
    if (!this.analysisIdValue) return
    
    window.open(`/analyses/${this.analysisIdValue}/download_pdf.pdf`, '_blank')
    
    const button = document.querySelector('.share-btn-secondary')
    const originalHTML = button.innerHTML
    
    button.innerHTML = '<i class="fas fa-check"></i><span>PDF généré !</span>'
    button.style.background = '#059669'
    button.style.color = 'white'
    
    setTimeout(() => {
      button.innerHTML = originalHTML
      button.style.background = '#f3f4f6'
      button.style.color = '#374151'
    }, 2000)
  }
  
  // Fermer sur clic overlay
  closeOnOverlayClick(event) {
    if (event.target.id === 'shareModal') {
      this.closeShare()
    }
    if (event.target.id === 'deleteModal') {
      this.closeDelete()
    }
  }
  
  disconnect() {
    // console.log("🧹 Modal controller disconnected")
  }
}