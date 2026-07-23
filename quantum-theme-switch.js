(function () {
  var palette = {
    '--sky': '#FF4FB3',
    '--sky2': '#FF8FCB',
    '--sun': '#FF8FCB',
    '--pink': '#E6007E',
    '--line': '#FFD4EA',
    '--soft': '#FFF6FB',
    '--good': '#17A66A',
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
    '--qp-bg': '#FFF6FB',
    '--qp-panel-soft': '#FFF8FC',
    '--qp-border': '#FFD4EA',
    '--qp-shadow': 'rgba(230,0,126,.18)'
  };

  var css = [
    'html{background:#fff!important;}',
    'body{background:linear-gradient(180deg,#fff 0%,#fff6fb 42%,#fff 100%)!important;}',
    'a{color:#B80063!important;}',
    '.qh-header,.hero{border-color:#FFD4EA!important;background:linear-gradient(135deg,#fff 0%,#fff6fb 56%,#fff 100%)!important;box-shadow:0 12px 30px rgba(230,0,126,.12)!important;}',
    '.qh-header:before,.hero:before{background:radial-gradient(circle,rgba(255,79,179,.26) 0 34%,rgba(255,143,203,.14) 35% 58%,transparent 59%)!important;}',
    '.hero:after{background:linear-gradient(90deg,#E6007E,#fff,#FF8FCB,#fff,#E6007E)!important;}',
    '.brand,.maker,.kicker,.label,.metric-label,.spec-name,.section-title,.section-title b,.bar-name,.gta-l,.io-count{color:#B80063!important;}',
    '.badge,.tag,.pill{border-color:#FF8FCB!important;color:#B80063!important;background:#fff!important;}',
    '.badge-row .badge:first-child,.tag.hot,.tag.cool,.cfg.on,.res button.on,.conn-count,.gta-badge{background:#E6007E!important;border-color:#E6007E!important;color:#fff!important;}',
    '.tag.sun{background:#FFF0F8!important;border-color:#FF8FCB!important;color:#B80063!important;}',
    '.section,.panel,.spec,.spec-card,.info-card,.metric-box,.status-box,.work-panel,.fps-panel,.gta-card,.app,.game,.cfg{border-color:#FFD4EA!important;background:#fff!important;}',
    '.panel,.spec,.info-card,.gta{border-top-color:#E6007E!important;}',
    '.section.dark,.copy-panel.dark{background:linear-gradient(180deg,#3A0624,#1E0312)!important;border-color:#B80063!important;}',
    '.dark .section-title,.dark .section-sub,.conn-desc,.benefit-txt span{color:#FFD4EA!important;}',
    '.conn-card{background:#3A0624!important;border-color:#B80063!important;}',
    '.fill{background:linear-gradient(90deg,#E6007E,#FF8FCB)!important;}',
    '.track{background:#FFE3F1!important;}',
    '.app.on,.game.on{background:#FFF0F8!important;border-color:#E6007E!important;}',
    '.gta{background:linear-gradient(135deg,#fff 0%,#fff6fb 54%,#fff 100%)!important;border-color:#FFD4EA!important;box-shadow:0 12px 30px rgba(230,0,126,.12)!important;}',
    '.gta:before{background:radial-gradient(circle,rgba(255,79,179,.22),transparent 62%)!important;}'
  ].join('\n');

  var root = document.documentElement;

  Object.keys(palette).forEach(function (name) {
    root.style.setProperty(name, palette[name]);
  });

  root.setAttribute('data-quantum-palette', 'classic');

  if (!document.getElementById('quantum-classic-theme')) {
    var style = document.createElement('style');
    style.id = 'quantum-classic-theme';
    style.textContent = css + [
      '.quantum-deposit-notice{margin:0 0 16px;padding:14px 16px;border:1px solid #FFD4EA;border-left:4px solid #E6007E;border-radius:10px;background:linear-gradient(135deg,#fff 0%,#fff6fb 100%);color:#3A0624;font-family:Verdana,Arial,sans-serif;font-size:13px;line-height:1.55;box-shadow:0 8px 24px rgba(230,0,126,.08)}',
      '.quantum-deposit-notice b{display:block;margin-bottom:6px;font-size:11px;letter-spacing:2px;color:#B80063;text-transform:uppercase}',
      '.quantum-deposit-notice span{display:block;color:#5c3a4d}'
    ].join('\n');
    document.head.appendChild(style);
  }

  function injectDepositNotice() {
    var title = document.title || '';
    if (/OUTLET/i.test(title)) return;
    if (document.getElementById('quantum-deposit-notice')) return;

    var box = document.createElement('div');
    box.id = 'quantum-deposit-notice';
    box.className = 'quantum-deposit-notice';
    box.innerHTML =
      '<b>Esta en deposito</b>' +
      '<span>Una vez abonado se realiza el llamado para que llegue al local y asi coordinar envio o retiro. ' +
      'El plazo de envio del deposito al local tiene un tiempo aproximado de 48 a 72 horas habiles.</span>';

    var container = document.querySelector('.container') || document.querySelector('.wrap') || document.body;
    if (container.firstChild) {
      container.insertBefore(box, container.firstChild);
    } else {
      container.appendChild(box);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectDepositNotice);
  } else {
    injectDepositNotice();
  }
})();
