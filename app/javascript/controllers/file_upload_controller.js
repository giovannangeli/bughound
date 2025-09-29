import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "dropZone", "filePreview", "fileInfo", "codeField", "charCounter", "warning"]
  
  connect() {
    console.log("FileUpload controller connected")
    this.setupFileInput()
  }
  
  setupFileInput() {
    // Reset file input on connect
    if (this.hasFileInputTarget) {
      this.fileInputTarget.value = ""
    }
  }
  
  openFileSelector(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (!this.hasFileInputTarget) return
    
    // Reset value to allow same file selection
    this.fileInputTarget.value = ""
    // Use click without timeout
    this.fileInputTarget.click()
  }
  
  handleFileChange(event) {
    const file = event.target.files[0]
    if (file) {
      this.processFile(file)
    }
  }
  
  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneTarget.classList.remove("drag-over")
    
    const file = event.dataTransfer.files[0]
    if (file) {
      // Set the file to input
      const dt = new DataTransfer()
      dt.items.add(file)
      this.fileInputTarget.files = dt.files
      this.processFile(file)
    }
  }
  
  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneTarget.classList.add("drag-over")
  }
  
  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropZoneTarget.classList.remove("drag-over")
  }
  
  processFile(file) {
    if (file.size > 1024 * 1024) {
      alert("Le fichier est trop volumineux (max 1MB)")
      return
    }
    
    // Update language based on extension
    const ext = file.name.split('.').pop().toLowerCase()
    const langMap = {
      'rb': 'Ruby', 'py': 'Python', 'js': 'JavaScript', 'ts': 'TypeScript',
      'cpp': 'C++', 'c': 'C++', 'java': 'Java', 'php': 'PHP',
      'go': 'Go', 'rs': 'Rust', 'sql': 'SQL', 'html': 'HTML',
      'css': 'CSS', 'sh': 'Bash', 'bash': 'Bash'
    }
    
    const langSelect = document.querySelector('select#analysis_language')
    if (langMap[ext] && langSelect) {
      langSelect.value = langMap[ext]
    }
    
    // Show file info
    const size = (file.size / 1024).toFixed(1) + ' KB'
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.textContent = `${file.name} (${size})`
    }
    
    // Show preview
    if (this.hasFilePreviewTarget) {
      this.filePreviewTarget.style.display = "block"
      this.filePreviewTarget.style.opacity = "0"
      setTimeout(() => {
        this.filePreviewTarget.style.transition = "opacity .3s ease"
        this.filePreviewTarget.style.opacity = "1"
      }, 10)
    }
    
    this.updateSubmitButtons()
  }
  
  removeFile(event) {
    event.preventDefault()
    
    if (this.hasFileInputTarget) {
      this.fileInputTarget.value = ""
    }
    
    if (this.hasFilePreviewTarget) {
      this.filePreviewTarget.style.display = "none"
    }
    
    this.updateSubmitButtons()
  }
  
  updateSubmitButtons() {
    const fileMode = document.querySelector('#file-mode')
    const textMode = document.querySelector('#text-mode')
    const textModeActive = textMode && textMode.style.display !== "none"
    
    let hasContent = false
    
    if (textModeActive) {
      hasContent = this.hasCodeFieldTarget && this.codeFieldTarget.value.trim().length >= 10
    } else {
      hasContent = this.hasFileInputTarget && this.fileInputTarget.files.length > 0
    }
    
    const buttons = document.querySelectorAll('.action-button')
    buttons.forEach(btn => {
      if (hasContent) {
        btn.style.pointerEvents = 'auto'
        btn.style.opacity = '1'
      } else {
        btn.style.pointerEvents = 'none'
        btn.style.opacity = '0.5'
      }
    })
    
    if (textModeActive && this.hasWarningTarget) {
      this.warningTarget.style.display = hasContent ? "none" : "flex"
    }
  }
}