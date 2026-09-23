export {};

/** @typedef {'idle'|'working'|'finished'|'needs-you'|'resting'|'hover'} Reaction */
/** @typedef {{strip: string, frameCount: number, playback: 'loop'|'once'|'hold', frames: {index: number, durationMs: number}[]}} Animation */
/** @typedef {{id: string, name: string, cell: {width: number, height: number}, animations: Record<Reaction, Animation>}} Avatar */

const AVATARS = ['block', 'soft-spark', 'ram', 'catpuccino'];
const ROOT = '../../../assets/avatars/';

const labels = {
  idle: ['Idle', 'A slow breath and an occasional blink.'],
  working: ['Working', 'A small, steady look of concentration.'],
  finished: ['Finished', 'A brief hop for a response ending.'],
  'needs-you': ['Needs you', 'A short wave, then a patient questioning pose.'],
  resting: ['Resting', 'Quiet rest when activity is uncertain or disconnected.'],
  hover: ['Happy hover', 'A little delight when you stop by.'],
};

const canvases = [...document.querySelectorAll('canvas')];
const contexts = canvases.map(canvas => canvas.getContext('2d'));
const pause = /** @type {HTMLButtonElement} */ (document.querySelector('button#pause'));
const replay = /** @type {HTMLButtonElement} */ (document.querySelector('button#replay'));
const name = document.querySelector('#name');
const description = document.querySelector('#description');
const frameLabel = document.querySelector('#frame');
const buttons = document.querySelector('#animations');
const hover = /** @type {HTMLInputElement} */ (document.querySelector('input#hover'));
const scale = /** @type {HTMLSelectElement} */ (document.querySelector('select#scale'));
const picker = /** @type {HTMLSelectElement} */ (document.querySelector('select#avatar'));
/** @type {Reaction} */
let selected = 'idle';
/** @type {Reaction} */
let active = 'idle';
let elapsed = 0;
let paused = matchMedia('(prefers-reduced-motion: reduce)').matches;
let previousTime = 0;
let hovering = false;

/** @param {string} id */
async function load(id) {
  const response = await fetch(`${ROOT}${id}/avatar.json`);
  if (!response.ok) throw new Error(`Could not load ${id}/avatar.json.`);
  /** @type {Avatar} */
  const avatar = await response.json();
  /** @type {Record<string, HTMLImageElement>} */
  const strips = {};
  for (const [key, animation] of Object.entries(avatar.animations)) {
    const image = new Image();
    image.src = new URL(`${ROOT}${id}/${animation.strip}`, location.href).href;
    await image.decode();
    if (image.width !== animation.frameCount * avatar.cell.width || image.height !== avatar.cell.height) {
      throw new Error(`${id}/${animation.strip} does not match its frame count.`);
    }
    strips[key] = image;
  }
  return { avatar, strips };
}

try {
  const loaded = await Promise.all(AVATARS.map(load));
  let { avatar: map, strips } = loaded[0];
  for (const [index, { avatar }] of loaded.entries()) {
    picker.append(new Option(avatar.name, String(index)));
  }
  picker.addEventListener('change', () => {
    ({ avatar: map, strips } = loaded[Number(picker.value)]);
    render();
  });
  for (const [key, [label]] of Object.entries(labels)) {
    const button = document.createElement('button');
    button.textContent = label;
    button.dataset.animation = key;
    button.addEventListener('click', () => { selected = /** @type {Reaction} */ (key); hovering = false; start(selected); });
    buttons.append(button);
  }

  /** @param {Reaction} key */
  function start(key) {
    active = key;
    elapsed = 0;
    previousTime = performance.now();
    name.textContent = labels[key][0];
    description.textContent = labels[key][1];
    for (const button of buttons.querySelectorAll('button')) {
      button.setAttribute('aria-pressed', String(button.dataset.animation === selected));
    }
    render();
  }

  function render() {
    const animation = map.animations[active];
    const total = animation.frames.reduce((sum, frame) => sum + frame.durationMs, 0);
    if (elapsed >= total && animation.playback === 'once') {
      // The production app chooses its current aggregate state; this study returns to idle.
      selected = 'idle';
      start(selected);
      return;
    }
    let time = animation.playback === 'loop' ? elapsed % total : Math.min(elapsed, total - 1);
    let current = animation.frames.at(-1);
    for (const frame of animation.frames) {
      if (time < frame.durationMs) { current = frame; break; }
      time -= frame.durationMs;
    }
    const { width, height } = map.cell;
    contexts.forEach((context, index) => {
      context.imageSmoothingEnabled = false;
      context.clearRect(0, 0, canvases[index].width, canvases[index].height);
      context.drawImage(strips[active], current.index * width, 0, width, height, 0, 0, width, height);
    });
    frameLabel.textContent = `Frame ${current.index + 1} of ${animation.frameCount} / ${animation.playback}${elapsed >= total && animation.playback === 'hold' ? ' · held' : ''}`;
  }

  function tick(now) {
    if (!paused && !document.hidden) elapsed += now - previousTime;
    previousTime = now;
    render();
    requestAnimationFrame(tick);
  }
  pause.disabled = false;
  replay.disabled = false;
  pause.textContent = paused ? 'Play' : 'Pause';
  pause.addEventListener('click', () => {
    paused = !paused;
    previousTime = performance.now();
    pause.textContent = paused ? 'Play' : 'Pause';
  });
  replay.addEventListener('click', () => start(selected));
  scale.addEventListener('change', () => {
    for (const canvas of canvases) {
      canvas.style.width = canvas.style.height = `${map.cell.width * Number(scale.value)}px`;
    }
  });
  for (const canvas of canvases) {
    canvas.addEventListener('pointerenter', () => {
      if (hover.checked) { hovering = true; start('hover'); }
    });
    canvas.addEventListener('pointerleave', () => {
      if (hovering) { hovering = false; start(selected); }
    });
  }
  hover.addEventListener('change', () => {
    if (!hover.checked && hovering) { hovering = false; start(selected); }
  });
  document.addEventListener('visibilitychange', () => { previousTime = performance.now(); });
  start(selected);
  requestAnimationFrame(tick);
} catch (error) {
  name.textContent = 'Preview unavailable';
  description.textContent = `${error.message} Serve the repository over HTTP; see assets/avatars/README.md.`;
}
