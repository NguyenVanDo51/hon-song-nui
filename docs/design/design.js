// shared by every docs/design page: data, nav, helpers, sound catalogue
'use strict';
const D = window.DESIGN;
const S = window.SCENE || null;
const SH = window.SHOTS || null;
const ROOT = '../../';
const SFX_DIR = ROOT + 'assets/sfx/';
const $ = (id) => document.getElementById(id);
const el = (tag, attrs = {}, html = '') => { const e = document.createElement(tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (html) e.innerHTML = html; return e; };
const fmt = (t) => `${Math.floor(t / 60)}:${String(Math.floor(t % 60)).padStart(2, '0')}`;
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

const PAGES = [
  ['index.html', 'Tổng quan'], ['tuong.html', 'Tướng'], ['linh.html', 'Lính'], ['dia-hinh.html', 'Địa hình'],
  ['am-thanh.html', 'Âm thanh'], ['giao-dien.html', 'Giao diện'], ['man-hinh.html', 'Màn hình'],
  ['noi-dung.html', 'Level & bản đồ'], ['chu.html', 'Chữ'],
];
(function nav() {
  const here = location.pathname.split('/').pop() || 'index.html';
  const top = el('div', { class: 'top' });
  top.innerHTML = `<div class="in"><h1><a href="index.html">Công Thành Chiến · Thành phần game</a></h1><nav>${
    PAGES.map(([f, n]) => `<a href="${f}"${f === here ? ' class="cur"' : ''}>${n}</a>`).join('')
  }</nav><div class="ver">game ${D.version}</div></div>`;
  document.body.prepend(top);
})();
const shot = (name) => (SH && SH.files.includes(name + '.png') ? `shots/${name}.png` : null);
const sideName = (s) => D.factions[s].name;

// ---------- sound catalogue (where each sound fires: play() call sites in scripts/ui/*.gd, 2026-11-09) ----------
const GROUPS = [
  { id: 'ui', name: 'Giao diện', color: 'var(--g-ui)', hex: '#8d7c63' },
  { id: 'board', name: 'Bàn cờ & kinh tế', color: 'var(--g-board)', hex: '#3f7a2e' },
  { id: 'fight', name: 'Đánh nhau', color: 'var(--g-fight)', hex: '#b3262e' },
  { id: 'end', name: 'Kết trận', color: 'var(--g-end)', hex: '#27477a' },
];
// where each sound fires: read from the play() call sites (scripts/ui/*.gd), 2026-11-09
const META = {
  ui: { g: 'ui', name: 'Ấn nút', when: ['Bấm mọi nút menu, nút lệnh (⚔ Đánh / 🏠 Chiếm / Chờ…), Hết lượt, ⚙, nút thẻ kết trận', 'Mở thẻ ⓘ thông tin quân, đóng thẻ giới thiệu quân', 'Lính ta bước ra khỏi lâu đài sau khi mua (vòng xanh)'], code: 'menus.gd _on · info_panel.gd _act · game_hud.gd · game_cards.gd · event_player.gd' },
  select: { g: 'ui', name: 'Chọn', when: ['Chạm chọn lính, chọn ô đích, ngắm mục tiêu', 'Tab = lính kế chưa đi', 'Chạm lâu đài mở bảng mua'], code: 'game_screen.gd _on_tile / select_next / _set_dest · info_panel.gd · turn_driver.gd' },
  page: { g: 'ui', name: 'Lật trang', when: ['Không chỗ nào gọi: có file nhưng game không phát'], code: 'chỉ định nghĩa trong audio.gd', unused: true },
  move: { g: 'board', name: 'Bước đi', when: ['Mỗi lần lính di chuyển (cả 2 phe)', 'Cảnh giới thiệu quân mới'], code: 'event_player.gd play · intro_stage.gd' },
  coin: { g: 'board', name: 'Tiền', when: ['Thu nhập đầu lượt', '+vàng hiện trên làng / lâu đài vừa chiếm', 'Hủy mua, hoàn vàng'], code: 'event_player.gd income_fx / _show_gains · game_screen.gd _unbuy_sel' },
  capture: { g: 'board', name: 'Chiếm', when: ['Chiếm làng / lâu đài (chuông D4 → A4 → hợp âm D)', 'Sửa làng hỏng'], code: 'fx.gd capture / repair' },
  heal: { g: 'board', name: 'Hồi máu', when: ['Lính hồi máu đầu lượt (đứng trên làng / lâu đài / đền)'], code: 'event_player.gd heal_fx' },
  drum: { g: 'board', name: 'Báo lượt', when: ['Băng rôn "Lượt N" / "Lượt địch" đầu mỗi lượt', '1 đấu 1: màn chuyển tay'], code: 'game_hud.gd banner · turn_driver.gd _handoff', note: 'Tên "drum" nhưng tiếng là chuông (A5 + E6 + A6), không phải trống.' },
  spawn: { g: 'board', name: 'Xuất hiện', when: ['Quân địch đợt mới hiện ra (wave)', 'Thẻ giới thiệu quân địch mới'], code: 'fx.gd spawn_fx · game_cards.gd intro_card' },
  rank: { g: 'board', name: 'Lên cấp', when: ['Lính lên cấp', 'Thẻ giới thiệu quân ta mới'], code: 'fx.gd rank · game_cards.gd intro_card' },
  raise: { g: 'board', name: 'Gọi hồn', when: ['Pháp sư gọi hồn dựng Bộ xương từ mộ'], code: 'fx.gd raise_fx' },
  slash: { g: 'fight', name: 'Vung đòn', when: ['Đòn cận chiến: tướng, Vệ binh, Hải tặc, Bộ xương'], code: 'rig/specs/*.gd sound("slash") · fx.gd attack' },
  arrow: { g: 'fight', name: 'Tên bay', when: ['Cung thủ bắn'], code: 'rig/specs/archer.gd · fx.gd attack' },
  orb: { g: 'fight', name: 'Phép', when: ['Pháp sư gọi hồn, Tu sĩ ánh sáng, Rồng đánh'], code: 'rig/specs/shaman.gd, drum.gd, bird.gd' },
  rock: { g: 'fight', name: 'Ném đá', when: ['Máy bắn đá ném', 'Máy bắn đá phá làng'], code: 'rig/specs/catapult.gd · fx.gd raze' },
  hit: { g: 'fight', name: 'Trúng đòn', when: ['Đòn trúng, sát thương < 35, quân không nặng'], code: 'rig.gd (impact) · fx.gd _impact' },
  heavy: { g: 'fight', name: 'Trúng mạnh', when: ['Đòn trúng ≥ 35 sát thương, hoặc quân nặng (tướng, Golem, Rồng) đánh', 'Đá máy bắn đá rơi; Golem vung đòn', 'Làng bị phá'], code: 'rig.gd (impact) · rig/specs/elephant.gd · fx.gd raze' },
  die: { g: 'fight', name: 'Ngã', when: ['Lính chết'], code: 'fx.gd death' },
  win: { g: 'end', name: 'Thắng', when: ['Thắng trận (chuông D5 → A5 → hợp âm D, ~2 s)'], code: 'turn_driver.gd' },
  lose: { g: 'end', name: 'Thua', when: ['Thua trận (chuông A4 → F4 → D4 đi xuống, ~1.8 s)'], code: 'turn_driver.gd' },
};
const groupOf = (k) => GROUPS.find((g) => g.id === (META[k] ? META[k].g : 'ui'));
let current = null;
function playFile(src, btn) {
  if (current) { current.a.pause(); current.b && current.b.classList.remove('playing'); }
  const a = new Audio(src);
  current = { a, b: btn };
  btn && btn.classList.add('playing');
  a.addEventListener('ended', () => btn && btn.classList.remove('playing'));
  a.play();
}
