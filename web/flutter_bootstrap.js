{{flutter_js}}
{{flutter_build_config}}

const progressBar = document.getElementById('progress_bar');
const progressTextBlack = document.getElementById('progress_text_black');
const progressTextWhite = document.getElementById('progress_text_white');
const statusText = document.getElementById('status_text');
const loaderWrapper = document.getElementById('loading_indicator');

let currentPercent = 0;
let targetPercent = 0;
let rafId = 0;
let lastRendered = -1;
let isCompleted = false;

function statusLabelFor(pct) {
  if (pct < 75) return 'Downloading Environment...';
  if (pct < 88) return 'Preparing Environment...';
  if (pct < 96) return 'Downloading Assets...';
  if (pct < 100) return 'Preparing Assets...';
  return 'Launching App...';
}

function renderProgress(pct) {
  const rounded = Math.round(pct);
  if (rounded === lastRendered) return;
  lastRendered = rounded;

  const label = rounded + '%';
  if (progressBar) progressBar.style.width = label;
  if (progressTextBlack) progressTextBlack.textContent = label;
  if (progressTextWhite) progressTextWhite.textContent = label;
  if (statusText) statusText.textContent = statusLabelFor(rounded);
}

function tickProgress() {
  rafId = 0;
  if (currentPercent < targetPercent) {
    const remaining = targetPercent - currentPercent;
    const step = isCompleted ? Math.max(2.5, remaining * 0.35) : Math.max(0.25, remaining * 0.08);
    currentPercent = Math.min(targetPercent, currentPercent + step);
    renderProgress(currentPercent);
    if (currentPercent < targetPercent) {
      rafId = requestAnimationFrame(tickProgress);
      return;
    }
  }

  if (isCompleted && currentPercent >= 100 && loaderWrapper) {
    loaderWrapper.classList.add('is-hidden');
    setTimeout(() => {
      if (loaderWrapper.parentNode) loaderWrapper.remove();
    }, 240);
  }
}

window.updateSplashProgress = function (initialPercent, nextTarget) {
  if (initialPercent > currentPercent) currentPercent = initialPercent;
  if (nextTarget > targetPercent) targetPercent = nextTarget;
  if (!rafId) rafId = requestAnimationFrame(tickProgress);
  return Promise.resolve();
};

window.completeSplash = function () {
  isCompleted = true;
  targetPercent = 100;
  currentPercent = 100;
  renderProgress(100);
  if (rafId) {
    cancelAnimationFrame(rafId);
    rafId = 0;
  }
  if (loaderWrapper) {
    loaderWrapper.classList.add('is-hidden');
    setTimeout(() => {
      if (loaderWrapper.parentNode) loaderWrapper.remove();
    }, 240);
  }
};

window.updateSplashProgress(0, 72);

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    window.updateSplashProgress(72, 88);
    const appRunner = await engineInitializer.initializeEngine();
    window.updateSplashProgress(88, 96);
    await appRunner.runApp();
  },
});
