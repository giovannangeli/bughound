import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // 1) (Re)mise en forme du contenu IA (smells / improve)
    this.styleSmells()
    this.styleImprove()

    // 2) Prism: sur la page actuelle uniquement
    this.highlightPrism()

    // 3) Boutons "Copier" (tests + code refactorisé), idempotent
    this.initCopyButtons()

    // 4) Nettoyage avant snapshot Turbo (évite de “geler” des éléments injectés)
    this.beforeCache = this.beforeCache.bind(this)
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  // === Actions depuis la vue ===
  copyUrl(event) {
    const url = event.currentTarget?.dataset?.analysisUrl
    if (!url) return

    const btn = event.currentTarget
    const original = btn.innerHTML
    const onDone = () => {
      btn.innerHTML = '<i class="fas fa-check"></i><span>Copié !</span>'
      setTimeout(() => (btn.innerHTML = original), 1500)
    }

    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(url).then(onDone).catch(() => { this.fallbackCopy(url); onDone() })
    } else {
      this.fallbackCopy(url); onDone()
    }
  }

  downloadPdf(event) {
    const id = event.currentTarget?.dataset?.analysisId
    if (!id) return
    window.open(`/analyses/${id}/download_pdf.pdf`, "_blank")
  }

  toggleCode(event) {
    const container = this.element.querySelector(".code-content-premium")
    const chevron   = this.element.querySelector(".code-chevron")
    if (!container || !chevron) return

    const show = (container.style.display === "none" || !container.style.display)
    container.style.display = show ? "block" : "none"
    chevron.style.transform = show ? "rotate(180deg)" : "rotate(0deg)"

    // Assure le highlight si on ouvre le bloc
    if (show) this.highlightPrism()
  }

  // === Prism ===
  highlightPrism() {
    if (!window.Prism) return
    // On limite le highlight à l’élément de show pour éviter les reflows globaux
    window.Prism.highlightAllUnder?.(this.element) || window.Prism.highlightAll()
  }

  // === Mise en forme "smells" ===
  styleSmells() {
    const wrapper = this.element.querySelector('[data-provider="smells"] .feedback-content-premium')
    if (!wrapper) return
    let html = wrapper.innerHTML

    const sections = [
      [/\*\*Synthèse\*\*/g,               '<div class="smells-section-title">Synthèse</div><div class="smells-synthese">'],
      [/\*\*Critiques \(🔴\)\*\*/g,       '</div><div class="smells-section-title">Critiques 🔴</div><div class="smells-critiques">'],
      [/\*\*Modérés \(🟡\)\*\*/g,         '</div><div class="smells-section-title">Modérés 🟡</div><div class="smells-moderes">'],
      [/\*\*Détail par catégories\*\*/g,  '</div><div class="smells-section-title">Détail par catégories</div><div class="smells-detail">'],
      [/\*\*Plan d'action\*\*/g,          '</div><div class="smells-section-title">Plan d\'action</div><div class="smells-plan">'],
      [/\*\*Impact pédagogique\*\*/g,     '</div><div class="smells-section-title">Impact pédagogique</div><div class="smells-impact">']
    ]
    sections.forEach(([re, repl]) => { html = html.replace(re, repl) })
    html += '</div>'
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    wrapper.innerHTML = html
  }

  // === Mise en forme "improve" ===
  styleImprove() {
    const wrapper = this.element.querySelector('[data-provider="improve"] .feedback-content-premium')
    if (!wrapper) return
    let html = wrapper.innerHTML

    // supprime les ** résiduels
    html = html.replace(/\*\*/g, '')

    html = html
      .replace(/Améliorations apportées.*?:/g, '<div class="improve-section-title">🎯 Améliorations apportées</div><div class="improve-ameliorations">')
      .replace(/Explications détaillées.*?:/g, '</div><div class="improve-section-title">📝 Explications détaillées</div><div class="improve-explications">')
      .replace(/Bénéfices obtenus.*?:/g,      '</div><div class="improve-section-title">🚀 Bénéfices obtenus</div><div class="improve-benefices">') + '</div>'

    wrapper.innerHTML = html
  }

  // === Boutons "Copier" custom sur tests/code refactorisé ===
  initCopyButtons() {
    // évite d’ajouter des doublons
    this.element.querySelectorAll('.custom-copy-btn').forEach(b => b.remove())

    const blocks = this.element.querySelectorAll('.tests-code-block .code-block, .code-card .code-block')
    blocks.forEach(block => {
      if (block.querySelector('.custom-copy-btn')) return
      const btn = document.createElement('button')
      btn.className = 'custom-copy-btn'
      btn.type = 'button'
      btn.textContent = 'Copier'
      btn.style.cssText = `
        position:absolute; top:1rem; right:1rem; z-index:20;
        background:#374151; color:#f8fafc; border:1px solid #4b5563;
        border-radius:8px; padding:.5rem .75rem; font-size:.875rem; cursor:pointer;
      `
      btn.addEventListener('click', (e) => {
        e.preventDefault(); e.stopPropagation()
        const codeEl = block.querySelector('code')
        const text = codeEl?.textContent || codeEl?.innerText || ''
        if (!text) return
        const done = () => { btn.textContent = 'Copié !'; setTimeout(() => btn.textContent = 'Copier', 1500) }
        if (navigator.clipboard?.writeText) {
          navigator.clipboard.writeText(text).then(done).catch(() => { this.fallbackCopy(text); done() })
        } else { this.fallbackCopy(text); done() }
      })
      block.appendChild(btn)
    })
  }

  // === Nettoyage avant cache Turbo ===
  beforeCache() {
    // enlève les boutons copiés pour que le snapshot reste clean
    this.element.querySelectorAll('.custom-copy-btn').forEach(b => b.remove())
  }

  // === utilitaires ===
  fallbackCopy(text) {
    const ta = document.createElement("textarea")
    ta.value = text
    document.body.appendChild(ta)
    ta.select()
    document.execCommand("copy")
    document.body.removeChild(ta)
  }
}
