function mon(face, size) {
  const ink = '#2A2106', l = 39, r = 61, y = 58;
  const s = `stroke="${ink}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
  const dots = `<circle cx="${l}" cy="${y}" r="3.6" fill="${ink}"/><circle cx="${r}" cy="${y}" r="3.6" fill="${ink}"/>`;
  const arcs = `<path d="M${l - 5} ${y + 2}q5-7 10 0M${r - 5} ${y + 2}q5-7 10 0" ${s}/>`;
  const smile = `<path d="M44 68q6 6 12 0" ${s}/>`;
  const f = {
    idle: dots + `<path d="M46 70h8" ${s}/>`,
    happy: arcs + smile,
    sleep: `<path d="M${l - 5} ${y}h10M${r - 5} ${y}h10M47 70h6" ${s}/><path d="M78 20h8l-8 9h8" ${s}/>`,
    worry: dots + `<path d="M${l - 6} ${y - 6}l9 -4M${r + 6} ${y - 6}l-9 -4M43 71q2.3-3 4.6 0t4.6 0 4.6 0" ${s}/>`,
    look: `<circle cx="${l + 3}" cy="${y + 1}" r="3.6" fill="${ink}"/><circle cx="${r + 3}" cy="${y + 1}" r="3.6" fill="${ink}"/><path d="M47 70h7" ${s}/>`,
    wink: `<circle cx="${l}" cy="${y}" r="3.6" fill="${ink}"/><path d="M${r - 5} ${y + 2}q5-7 10 0" ${s}/>` + smile
  }[face] || '';
  return `<svg viewBox="0 0 100 110" width="${size}" height="${size * 1.1}" aria-hidden="true">
<g transform="rotate(-10 50 56)"><ellipse cx="50" cy="58.5" rx="32" ry="46" fill="#C99A22"/><ellipse cx="50" cy="56" rx="32" ry="46" fill="#F2C94C"/></g>${f}</svg>`;
}
document.querySelectorAll('.mon').forEach((el) => { el.innerHTML = mon(el.dataset.face, Number(el.dataset.size)); });
