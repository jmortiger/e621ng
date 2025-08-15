/** @module PWA Progressive Web App logic */

// cspell:words beforeinstallprompt infobar

// // Initialize deferredPrompt for use later to show browser install prompt.
// let deferredPrompt;

// window.addEventListener('beforeinstallprompt', (e) => {
//   // Prevent the mini-infobar from appearing on mobile
//   e.preventDefault();
//   // Stash the event so it can be triggered later.
//   deferredPrompt = e;
//   // Update UI notify the user they can install the PWA
//   showInstallPromotion();
//   // Optionally, send analytics event that PWA install promo was shown.
//   console.log(`'beforeinstallprompt' event was fired.`);
// });

// /**
//  * Checks if the PWA can be installed.
//  * @returns {boolean}
//  */
// const isInStandaloneMode = () => (window.matchMedia('(display-mode: standalone)').matches) ||
//   (window.navigator.standalone) || // iOS Safari only
//   document.referrer.includes('android-app://');

// /**
//  * Checks if the PWA can be installed & activates the prompt for it if it can
//  */
// const handlePrompt = () => {
//   if (isInStandaloneMode()) {
//     console.log("webapp is installed")
//   }
// };
class PwaUtils {
  /**
   * @type {BeforeInstallPromptEvent | Event | null}
   * Initialize deferredPrompt for use later to show browser install prompt.
   */
  static deferredPrompt;
  // constructor() {
  //   
  // }

  /**
   * Checks if the PWA can be installed.
   * @returns {boolean}
   */
  static get isInStandaloneMode() {
    return (window.matchMedia('(display-mode: standalone)').matches) ||
      (window.navigator.standalone) || // iOS Safari only
      document.referrer.includes('android-app://');
  }

  /**
   * 
   */
  static initPwa() {
    if (this.isInStandaloneMode) {
      console.log("Running in PWA");
      // TODO: Service worker
    }
  };

  /**
   * ~~Checks if the PWA can be installed & activates the prompt for it if it can~~
   */
  static handlePrompt() {
    if (this.isInStandaloneMode) {
      return;
    } else { // TODO: Store a date the prompt was last shown & don't show it again if it's the same day
      console.log("Should show install prompt");
      // TODO: Set up install prompt
      this.showInstallPromotion();
    }
  };

  static showInstallPromotion() {

  }

  /**
   * Only fired if it can be installed & isn't already.
   * @param {Event} e BeforeInstallPromptEvent
   */
  static onBeforeInstallPromptEvent(e) {
    // Prevent the mini-infobar from appearing on mobile
    e.preventDefault();
    // Stash the event so it can be triggered later.
    PwaUtils.deferredPrompt = e;
    console.log(e);
    // Update UI notify the user they can install the PWA
    /** @type {HTMLElement} */
    const installLi = document.querySelector("#nav-install");
    // installLi.dataset[ "should-show" ] = true;
    // installLi.className += " hidden already-installed"
    installLi.classList.remove("should-hide");
    /** @type {HTMLElement} */
    const installLink = document.querySelector("#nav-install-link");
    installLink.onclick = PwaUtils.onInstallClick;
    PwaUtils.showInstallPromotion();
    // Optionally, send analytics event that PWA install promo was shown.
    console.log(`'beforeinstallprompt' event was fired.`);
  }

  static onInstallClick(e) {
    e.preventDefault();
    console.log(`'Install' button clicked.`);
    PwaUtils.deferredPrompt.prompt();
  }
}

window.addEventListener('beforeinstallprompt', PwaUtils.onBeforeInstallPromptEvent);

export default PwaUtils;