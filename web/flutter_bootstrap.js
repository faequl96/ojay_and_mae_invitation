{{flutter_js}}
{{flutter_build_config}}

const progressBar = document.getElementById('progress_bar');
const progressTextBlack = document.getElementById('progress_text_black');
const progressTextWhite = document.getElementById('progress_text_white');
const statusText = document.getElementById('status_text');
const loaderWrapper = document.getElementById('loading_indicator');

let currentPercent = 0;
let progressTimeout;
let pendingResolve;

window.updateSplashProgress = function(initialPercent, targetPercent, minMs = 50, maxMs = 150) {
  if (pendingResolve) {
    pendingResolve();
    pendingResolve = null;
  }

  return new Promise((resolve) => {
    pendingResolve = resolve;
    
    clearTimeout(progressTimeout);
    currentPercent = initialPercent;

    function step() {
      if (currentPercent < targetPercent) {
        currentPercent += 1;
        
        if (progressBar) progressBar.style.width = currentPercent + '%';
        if (progressTextBlack) progressTextBlack.textContent = currentPercent + '%';
        if (progressTextWhite) progressTextWhite.textContent = currentPercent + '%';

        if (statusText) {
          if (currentPercent < 76) statusText.textContent = "Downloading Environment...";
          else if (currentPercent < 81) statusText.textContent = "Preparing Environment...";
          else if (currentPercent < 96) statusText.textContent = "Downloading Assets...";
          else if (currentPercent < 100) statusText.textContent = "Preparing Assets...";
          else statusText.textContent = "Launching App...";
        }

        const randomInterval = Math.floor(Math.random() * (maxMs - minMs + 1)) + minMs;
        progressTimeout = setTimeout(step, randomInterval);
      } else {
        const finishResolve = pendingResolve;
        pendingResolve = null;

        if (currentPercent >= 100 && loaderWrapper) {
          setTimeout(() => {
            if (finishResolve) finishResolve();
            setTimeout(() => {
              if (loaderWrapper.parentNode) loaderWrapper.remove();
            }, 800);
          }, 400);
        } else {
          if (finishResolve) finishResolve();
        }
      }
    }

    // Mulai langkah pertama
    step();
  });
}

updateSplashProgress(0, 75, 20, 280);

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    updateSplashProgress(75, 80, 100, 150);
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});