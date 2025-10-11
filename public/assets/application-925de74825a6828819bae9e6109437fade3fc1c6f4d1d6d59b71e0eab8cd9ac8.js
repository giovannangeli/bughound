import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

const application = Application.start()
window.Stimulus = application

// Configure Stimulus development experience
application.debug = false

// Load all controllers
import CarouselController from "controllers/carousel_controller"
import DropdownController from "controllers/dropdown_controller"
import FileUploadController from "controllers/file_upload_controller"
import HelloController from "controllers/hello_controller"
import MobileMenuController from "controllers/mobile_menu_controller"
import ModalController from "controllers/modal_controller"
import NavbarController from "controllers/navbar_controller"
import ShowController from "controllers/show_controller"
import UserMenuController from "controllers/user_menu_controller"

application.register("carousel", CarouselController)
application.register("dropdown", DropdownController)
application.register("file-upload", FileUploadController)
application.register("hello", HelloController)
application.register("mobile-menu", MobileMenuController)
application.register("modal", ModalController)
application.register("navbar", NavbarController)
application.register("show", ShowController)
application.register("user-menu", UserMenuController);
