document.addEventListener('DOMContentLoaded', () => {
  // 1. Mobile navigation drawer toggle
  const menuToggle = document.getElementById('menuToggle');
  const mobileDrawer = document.getElementById('mobileDrawer');
  if (menuToggle && mobileDrawer) {
    menuToggle.addEventListener('click', () => {
      const open = mobileDrawer.hidden;
      mobileDrawer.hidden = !open;
      menuToggle.setAttribute('aria-expanded', String(open));
    });
    mobileDrawer.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', () => {
        mobileDrawer.hidden = true;
        menuToggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  // 2. Render 22-tick daily goal progress bar (inspired directly by HomeScreen)
  const ticksEl = document.getElementById('heroTicks');
  if (ticksEl) {
    const totalTicks = 22;
    const filledTicks = Math.round((5.24 / 8) * totalTicks);
    for (let i = 0; i < totalTicks; i++) {
      const bar = document.createElement('span');
      bar.className = i < filledTicks ? 'tick on' : 'tick';
      ticksEl.appendChild(bar);
    }
  }

  // 3. Interactive phone screen tabs
  const previewImg = document.getElementById('phonePreviewImg');
  const previewCaption = document.getElementById('phoneCaption');
  const ptabButtons = document.querySelectorAll('.ptab');
  const screenPaths = {
    home: './assets/screens/home.png',
    map: './assets/screens/map.png',
    territory: './assets/screens/territory.png',
    clan: './assets/screens/clan.png',
    profile: './assets/screens/profile.png',
  };

  ptabButtons.forEach((btn) => {
    btn.addEventListener('click', () => {
      const key = btn.getAttribute('data-screen');
      const caption = btn.getAttribute('data-caption') || '';
      if (!key || !screenPaths[key] || !previewImg) return;

      ptabButtons.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      previewImg.src = screenPaths[key];
      previewImg.alt = `Harakatlan ${key} ekrani`;
      if (previewCaption) previewCaption.textContent = caption;
    });
  });

  // 4. Showcase map mode switcher (Jonli GPS Xarita vs Taktik Orol)
  const mapModeImg = document.getElementById('mapModeImg');
  const mapModeTag = document.getElementById('mapModeTag');
  const modeBtns = document.querySelectorAll('.mode-btn');
  modeBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      const mode = btn.getAttribute('data-mapmode');
      modeBtns.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      if (!mapModeImg || !mapModeTag) return;

      if (mode === 'island') {
        mapModeImg.src = './assets/images/map.jpg';
        mapModeImg.alt = 'Taktik Orol xaritasi';
        mapModeTag.textContent = "Taktik Orol · Raqib qal'alariga hujum";
      } else {
        mapModeImg.src = './assets/screens/map.png';
        mapModeImg.alt = 'Jonli GPS Xarita';
        mapModeTag.textContent = 'Amir Temur xiyoboni · Jonli GPS';
      }
    });
  });

  // 5. Interactive Step-to-Army & Castle Level Simulator
  const kmSlider = document.getElementById('kmSlider');
  const simKm = document.getElementById('simKm');
  const simTiles = document.getElementById('simTiles');
  const simInfantry = document.getElementById('simInfantry');
  const simCavalry = document.getElementById('simCavalry');
  const simArchers = document.getElementById('simArchers');
  const simLevel = document.getElementById('simLevel');

  function updateSimulator(kmVal) {
    const km = Number(kmVal);
    const tiles = Math.floor(km);
    const infantry = Math.round(km * 20);
    const cavalry = Math.round(km * 6);
    const archers = Math.round(km * 3);
    const level = tiles >= 15 ? 3 : tiles >= 5 ? 2 : 1;

    if (simKm) simKm.textContent = km.toFixed(1);
    if (simTiles) simTiles.textContent = `+${tiles} katak`;
    if (simInfantry) simInfantry.textContent = `${infantry} ta`;
    if (simCavalry) simCavalry.textContent = `${cavalry} ta`;
    if (simArchers) simArchers.textContent = `${archers} ta`;
    if (simLevel) simLevel.textContent = `${level}-daraja`;
  }

  if (kmSlider) {
    updateSimulator(kmSlider.value);
    kmSlider.addEventListener('input', (e) => updateSimulator(e.target.value));
  }

  // 6. 14 Uzbekistan regions league interactive selector
  const regions = [
    { name: 'Toshkent shahri', coords: '41.31° N, 69.28° E' },
    { name: 'Toshkent viloyati', coords: '41.29° N, 69.34° E' },
    { name: 'Samarqand viloyati', coords: '39.65° N, 66.96° E' },
    { name: 'Buxoro viloyati', coords: '39.77° N, 64.46° E' },
    { name: "Farg'ona viloyati", coords: '40.38° N, 71.78° E' },
    { name: 'Andijon viloyati', coords: '40.78° N, 72.34° E' },
    { name: 'Namangan viloyati', coords: '41.00° N, 71.67° E' },
    { name: 'Qashqadaryo viloyati', coords: '38.86° N, 65.79° E' },
    { name: 'Surxondaryo viloyati', coords: '37.23° N, 67.28° E' },
    { name: 'Xorazm viloyati', coords: '41.55° N, 60.63° E' },
    { name: 'Jizzax viloyati', coords: '40.12° N, 67.84° E' },
    { name: 'Navoiy viloyati', coords: '40.08° N, 65.38° E' },
    { name: 'Sirdaryo viloyati', coords: '40.84° N, 68.66° E' },
    { name: "Qoraqalpog'iston Resp.", coords: '42.46° N, 59.62° E' },
  ];

  const regionGrid = document.getElementById('regionGrid');
  const activeRegionLabel = document.getElementById('activeRegionLabel');

  if (regionGrid) {
    regions.forEach((reg, idx) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = idx === 0 ? 'region-pill active' : 'region-pill';
      btn.setAttribute('role', 'option');
      btn.setAttribute('aria-selected', idx === 0 ? 'true' : 'false');

      const nameSpan = document.createElement('span');
      nameSpan.textContent = reg.name;

      const statusSmall = document.createElement('small');
      statusSmall.textContent = idx === 0 ? 'Faol' : 'Liga';

      btn.appendChild(nameSpan);
      btn.appendChild(statusSmall);

      btn.addEventListener('click', () => {
        regionGrid.querySelectorAll('.region-pill').forEach((p) => {
          p.classList.remove('active');
          p.setAttribute('aria-selected', 'false');
          const sm = p.querySelector('small');
          if (sm) sm.textContent = 'Liga';
        });
        btn.classList.add('active');
        btn.setAttribute('aria-selected', 'true');
        statusSmall.textContent = 'Faol';
        if (activeRegionLabel) {
          activeRegionLabel.textContent = `${reg.name} ligasi · ${reg.coords}`;
        }
      });

      regionGrid.appendChild(btn);
    });
  }
});
