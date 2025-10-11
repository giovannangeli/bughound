# config/importmap.rb

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

# Pin each controller individually from the precompiled assets
pin "controllers/application", to: "controllers/application.js", preload: true
pin "controllers/carousel_controller", to: "controllers/carousel_controller.js", preload: true
pin "controllers/dropdown_controller", to: "controllers/dropdown_controller.js", preload: true
pin "controllers/file_upload_controller", to: "controllers/file_upload_controller.js", preload: true
pin "controllers/hello_controller", to: "controllers/hello_controller.js", preload: true
pin "controllers/mobile_menu_controller", to: "controllers/mobile_menu_controller.js", preload: true
pin "controllers/modal_controller", to: "controllers/modal_controller.js", preload: true
pin "controllers/navbar_controller", to: "controllers/navbar_controller.js", preload: true
pin "controllers/show_controller", to: "controllers/show_controller.js", preload: true
pin "controllers/user_menu_controller", to: "controllers/user_menu_controller.js", preload: true
pin "controllers/index", to: "controllers/index.js", preload: true