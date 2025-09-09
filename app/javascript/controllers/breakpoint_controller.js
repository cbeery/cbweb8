// app/javascript/controllers/breakpoint_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["banner", "currentBreakpoint", "windowSize"]
    static values = { 
        enabled: Boolean,
        height: { type: String, default: "1.5rem" }
    }

    connect() {
        // Tailwind breakpoints (in pixels)
        this.breakpoints = {
            '2xl': 1536,
            'xl': 1280,
            'lg': 1024,
            'md': 768,
            'sm': 640
        }
        
        this.isVisible = false
        this.setupBanner()
        this.checkInitialState()
        this.setupEventListeners()
        this.updateBreakpoint()
        
        // Make globally accessible
        window.breakpointBanner = this
        
        console.log('Breakpoint controller connected')
    }

    disconnect() {
        this.cleanup()
    }

    setupBanner() {
        // Banner should already exist in the DOM from the layout
        if (!this.hasBannerTarget) {
            console.warn("Breakpoint banner target not found")
            return
        }
        
        // Set initial hidden state
        this.bannerTarget.classList.add('-translate-y-full')
    }

    checkInitialState() {
        // Check URL parameter first
        const urlParams = new URLSearchParams(window.location.search)
        const showBanner = urlParams.get('show-breakpoints')
        
        // Check localStorage for persistent state
        const storedState = localStorage.getItem('breakpoint-banner-enabled')
        
        // Check if enabled via Rails environment variable
        const railsEnabled = this.enabledValue
        
        if (showBanner !== null) {
            this.isVisible = showBanner === 'true'
            localStorage.setItem('breakpoint-banner-enabled', this.isVisible)
        } else if (railsEnabled) {
            this.isVisible = true
            localStorage.setItem('breakpoint-banner-enabled', this.isVisible)
        } else if (storedState !== null) {
            this.isVisible = storedState === 'true'
        } else {
            this.isVisible = false // Default to hidden
        }
        
        this.updateVisibility()
    }

    setupEventListeners() {
        // Bind methods to preserve 'this' context
        this.handleResize = this.updateBreakpoint.bind(this)
        this.handleKeydown = this.handleKeyboardShortcut.bind(this)
        
        // Listen for resize events
        window.addEventListener('resize', this.handleResize)
        
        // Listen for keyboard shortcut (Ctrl/Cmd + B)
        document.addEventListener('keydown', this.handleKeydown)
        
        // Listen for Turbo navigation
        document.addEventListener('turbo:load', this.handleResize)
    }

    handleKeyboardShortcut(event) {
        if ((event.ctrlKey || event.metaKey) && event.key === 'b') {
            event.preventDefault()
            this.toggle()
        }
    }

    getCurrentBreakpoint() {
        const width = window.innerWidth
        
        for (const [name, minWidth] of Object.entries(this.breakpoints)) {
            if (width >= minWidth) {
                return name
            }
        }
        
        return 'xs' // Below sm breakpoint
    }

    updateBreakpoint() {
        if (!this.hasCurrentBreakpointTarget || !this.hasWindowSizeTarget) return
        
        const currentBreakpoint = this.getCurrentBreakpoint()
        const windowWidth = window.innerWidth
        
        this.currentBreakpointTarget.textContent = currentBreakpoint
        this.windowSizeTarget.textContent = `${windowWidth}px`
        
        // Update banner color based on breakpoint
        this.updateBannerColor(currentBreakpoint)
    }

    updateBannerColor(breakpoint) {
        if (!this.hasBannerTarget) return
        
        // Remove existing color classes
        const colorClasses = ['bg-red-600', 'bg-orange-600', 'bg-yellow-600', 'bg-green-600', 'bg-blue-600', 'bg-purple-600', 'bg-gray-600']
        this.bannerTarget.classList.remove(...colorClasses)
        
        // Add color based on breakpoint
        const colors = {
            'xs': 'bg-red-600',
            'sm': 'bg-orange-600',
            'md': 'bg-yellow-600',
            'lg': 'bg-green-600',
            'xl': 'bg-blue-600',
            '2xl': 'bg-purple-600'
        }
        
        this.bannerTarget.classList.add(colors[breakpoint] || 'bg-gray-600')
    }

    toggle() {
        this.isVisible = !this.isVisible
        localStorage.setItem('breakpoint-banner-enabled', this.isVisible)
        this.updateVisibility()
    }

    show() {
        this.setVisible(true)
    }

    hide() {
        this.setVisible(false)
    }

    setVisible(visible) {
        this.isVisible = visible
        localStorage.setItem('breakpoint-banner-enabled', this.isVisible)
        this.updateVisibility()
    }

    updateVisibility() {
        if (!this.hasBannerTarget) return
        
        if (this.isVisible) {
            this.bannerTarget.classList.remove('-translate-y-full')
            this.bannerTarget.classList.add('translate-y-0')
            document.body.style.paddingTop = this.heightValue
        } else {
            this.bannerTarget.classList.add('-translate-y-full')
            this.bannerTarget.classList.remove('translate-y-0')
            document.body.style.paddingTop = ''
        }
    }

    cleanup() {
        // Remove event listeners
        if (this.handleResize) {
            window.removeEventListener('resize', this.handleResize)
        }
        if (this.handleKeydown) {
            document.removeEventListener('keydown', this.handleKeydown)
        }
        
        // Reset body padding
        document.body.style.paddingTop = ''
    }
}