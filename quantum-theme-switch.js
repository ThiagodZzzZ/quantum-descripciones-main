(function () {
  var WORLD_CUP_END_AR = '2026-07-20T00:00:00-03:00';
  var classicMode = Date.now() >= new Date(WORLD_CUP_END_AR).getTime();

  var palettes = {
    worldcup: {
      '--sky': '#43A1D5',
      '--sky2': '#5FD0FF',
      '--sun': '#F0B800',
      '--pink': '#43A1D5',
      '--line': '#D7EDF8',
      '--soft': '#F7FBFF',
      '--qh-primary': '#43A1D5',
      '--qh-primary-dark': '#197AA0',
      '--qh-primary-soft': '#EAF9FF',
      '--qh-accent': '#43A1D5',
      '--qh-accent-2': '#F0B800',
      '--qh-sky': '#43A1D5',
      '--qh-sky-2': '#5FD0FF',
      '--qh-sky-soft': '#EAF9FF',
      '--qh-blue': '#43A1D5',
      '--qh-blue-2': '#5FD0FF',
      '--qh-line': '#D7EDF8',
      '--qh-bg': '#FFFFFF',
      '--qp-primary': '#43A1D5',
      '--qp-primary-dark': '#197AA0',
      '--qp-accent': '#F0B800',
      '--qp-border': '#D7EDF8'
    },
    classic: {
      '--sky': '#FF4FB3',
      '--sky2': '#FF8FCB',
      '--sun': '#FF8FCB',
      '--pink': '#E6007E',
      '--line': '#FFD4EA',
      '--soft': '#FFF6FB',
      '--qh-primary': '#E6007E',
      '--qh-primary-dark': '#B80063',
      '--qh-primary-soft': '#FFF0F8',
      '--qh-accent': '#FF4FB3',
      '--qh-accent-2': '#FF8FCB',
      '--qh-sky': '#FF4FB3',
      '--qh-sky-2': '#FF8FCB',
      '--qh-sky-soft': '#FFF0F8',
      '--qh-blue': '#E6007E',
      '--qh-blue-2': '#FF8FCB',
      '--qh-line': '#FFD4EA',
      '--qh-bg': '#FFFFFF',
      '--qp-primary': '#E6007E',
      '--qp-primary-dark': '#B80063',
      '--qp-accent': '#FF4FB3',
      '--qp-border': '#FFD4EA'
    }
  };

  var selected = classicMode ? palettes.classic : palettes.worldcup;
  var root = document.documentElement;

  Object.keys(selected).forEach(function (name) {
    root.style.setProperty(name, selected[name]);
  });

  root.setAttribute('data-quantum-palette', classicMode ? 'classic' : 'worldcup');
})();
