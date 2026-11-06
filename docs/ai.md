# AI: tham số, tự đấu, độ khó

## Tham số (`scripts/core/ai.gd`)
- Mọi hằng số chấm điểm ở `AI.DEFAULT` (1 Dictionary): trọng số khoảng cách tới mục tiêu, thủ địa hình, thận trọng (lính / tướng), giá máu / giá chết, hồi máu, về nhà, thành, chiếm, đánh, nhiễu, mua lính.
- Ghi đè theo phe: `s.aiParams = { "e": { "noise": 40.0, ... } }` (dict thiếu khóa cũng được, gộp lên `DEFAULT`, nhớ trong `mem` theo lượt). Không có `aiParams` = `DEFAULT`, file lưu không đổi, golden không đổi.
- Lính máu thấp: hp < `home_hp` (50) -> mục tiêu = ô hồi máu của phe (làng / thành của ta, đền) còn trống -> đi về qua nhiều lượt; thưởng `heal_hp` (< 70) giữ nó trên ô tới ~70 máu rồi quay lại đánh. Ô hồi gần nhất xa hơn `home_turns` (4) lượt đi / không có -> mục tiêu thường, lính thường bỏ sợ chết (không ngồi ỳ). Mục tiêu màn "tới đích" vẫn ưu tiên.
- Thử: `sim/probes/sulk.gd -- scene` (1 lính máu 25 ở xa nhà, địch đứng yên: vị trí / máu mỗi lượt), `-- scan 4` (mọi màn + đấu tự do: lính < 50 máu ngoài ô hồi -> đánh / về nhà / ỳ), `sim/probes/ai_time.gd` (ms mỗi nước AI).

## Tự đấu (`sim/tune.gd`, `tools/tune.sh`)
- `match a=<spec> b=<spec> games=N salt=S`: A (phe p) vs B (phe e) rồi đổi chỗ, trên mọi bản đồ đấu tự do (`Content.SKIRMISH.MAPS`, 3 bản) -> điểm A (thắng 1, hòa 0.5), 6·N ván. Seed: ván k của salt -> `1000 + (salt·64 + k)·7919` (LCG như `sim_lib`). Cùng params -> đúng 0.500 (kiểm tra).
- `evolve out=<file> games=8 minutes=20 island=k thr=0.55`: đột biến ~3 khóa của best (×exp(N(0, 0.3)), `noise` + `cap_last` giữ nguyên), đấu con vs best; giữ con khi > thr trên 2 bộ seed (2·48 ván). Ghi `var_to_str({gen, best, history})` sau mỗi thế hệ -> chạy lại cùng file = tiếp tục.
- `tools/tune.sh [islands] [minutes] [games] [held_games]`: các đảo chạy song song (mỗi đảo 1 tiến trình, `run_guarded`), rồi mỗi best vs `DEFAULT` trên seed giữ riêng (salt 9000000, `held_games`·6 ván); đảo tốt nhất (nếu > 0.5) -> `sim/tuned_params.txt`. Không đổi AI mặc định của game.
- `presets games=N [names=easy,normal,hard_v1,hard_v2]`: vòng tròn các mức độ khó (bên dưới).
- Spec: `hard_v1` = Khó trước planner (cố định, thước đo), `hard_v2` = `AI.PRESETS.hard`; ghi đè `<spec>+khóa:giá trị` (vd `hard_v2+pl_kill:2`). `time a= b= games=` = ms mỗi bước / lượt của A. `log=1` = 1 dòng mỗi ván (thắng, lý do, lượt, số lần tướng chết).

### Phiên tune 2026-11-06 (AI `5a75b2a` = `fe83a5d` + bảng tham số, Mac 10 nhân, chạy chung máy với việc khác)
- `tools/tune.sh 6 25 8 16`: 6 đảo × 25 phút, 12–13 thế hệ / đảo (48 ván / thế hệ, 96 khi xác nhận; 576–624 ván / đảo), 2 lần nhận.
- Tốc độ: ~1,0 ván/s một tiến trình khi máy rảnh; 0,4 ván/s mỗi đảo khi 6 đảo + việc khác (tổng ~2,4 ván/s); 4 tiến trình: ~0,65 ván/s mỗi cái.
- Ván có lợi thế ghế theo bản đồ (DEFAULT vs DEFAULT: dong_bang phe e thắng ~80%, nui_rung phe p ~75%) -> luôn đấu cả 2 ghế.
- Best (đảo 5): `hp_cap` 150 -> 81,3, `kill_hero` 600 -> 552 (lính rẻ cũng tính giá chết -> ít lao vào chỗ chết). Vs `DEFAULT`: 0,562 / 96 ván (seed chọn đảo), **0,573 / 384 ván seed mới** (salt 9000001–4; ~2,9 SE). Đảo 2 (`caution` 0,6 -> 0,94): 0,531 / 96. 4 đảo còn lại không nhận con nào (0,500).
- Ghi vào `sim/tuned_params.txt`; AI mặc định của game **không đổi**.

## Khó v2: lập kế hoạch cả lượt (`scripts/core/ai_plan.gd`, 2026-11-07)
`AI.PRESETS.hard` = knob v1 (`hp_cap`, `kill_hero`) + `"planner": 2` -> `AI.next_step` chuyển sang `AIPlan.next_step`. Không có `planner` (chiến dịch, đấu tự do, Thường, Dễ, gợi ý, golden) = `AI.greedy_step` = AI cũ y nguyên.

### Cách chạy
- Đầu lượt: tạo vài **lượt ứng viên** (portfolio), mỗi cái = tiền tố bắt buộc + AI tham lam v1 đi nốt lượt:
  1. `STYLES` (`pl_cands` = 3 bộ knob đầu): như cũ / không nhiễu / liều (`caution` 0, `atk_bias` 80).
  2. **Dồn đòn giết** (`kill_prefixes`, `pl_kill` = 3): với 3 địch giá trị nhất đánh tới được, chuỗi đòn giết hẳn nó (roll giữa): có đòn giết ngay -> quân rẻ nhất ra đòn kết (ưu tiên giết chắc ở roll thấp nhất); chưa giết được -> đòn có (sát thương × giá địch − phản đòn × giá ta) cao nhất (cung / máy bắn đá không bị phản đòn -> đánh trước). Thêm 1 ứng viên giết đôi (mục tiêu 1 rồi mục tiêu kế).
  3. **Giữ thành** (`guard_prefix`, `pl_guard` = 1): thành ta mà tướng địch bước tới được lượt sau -> quân đang đứng đó ở lại, thành trống -> quân rẻ nhất tới được vào đứng.
- Mỗi ứng viên chơi trên bản sao state (`Game.fixed_roll` 0,5), rồi **địch đáp 1 lượt** bằng AI tham lam v1 (Thường, không nhiễu), hết lượt (thu nhập, hồi máu) -> chấm điểm thế cờ (2 ply):
  - mỗi quân: giá (`AI.value`) × máu, nhưng phần phụ thuộc máu chặn ở `pl_hp_cap` 200 (máu hồi được; phần còn lại tính khi còn sống) -> tướng 900: 700 + 200 × máu.
  - + vàng, + thu nhập × 4 lượt, + 300 / thành, − 4 / ô quân tới công trình chưa của mình, − 12 / ô tướng tới thành chưa của mình; thắng / thua = ±1e6. Đối xứng (ta − địch).
- Ứng viên điểm cao nhất -> các bước của nó phát ra từng bước (UI vẫn diễn từng bước). Mỗi bước: tập id quân còn sống phải khớp dự đoán (roll thật giết / không giết khác roll giữa) + bước còn hợp lệ, không thì **lập lại** cho phần còn lại (`pl_replan` = 3 style + giết + giữ thành).
- Tất định: RNG riêng seed `hash([s.rng, s.turn, side, lần lập, id còn sống])`; không đụng `AI.rng` (trả lại đúng giá trị cũ, cả `Game.fixed_roll`); không sửa `s`. Giới hạn = số ứng viên (đếm được); `pl_ms` 4000 ms chỉ là phanh khẩn cấp (đo: không bao giờ chạm).
- Cache reach / threat / dist field (`mem.tm` / `rc` / `df`) dùng chung cho mọi bản sao trong lượt (khóa theo vị trí quân + địa hình -> an toàn).

### Nguồn tham khảo (đọc 2026-11-06)
- Battle for Wesnoth: đánh giá tổ hợp đòn (`src/ai/default/attack.cpp` `attack_analysis::rating`: `chance_to_kill × target_value − avg_losses × (1 − aggression)`, phạt phơi quân theo vulnerability / support, đòn đe dọa tướng ×5) + RCA AI (combat chạy trước chiếm làng / di chuyển) — https://github.com/wesnoth/wesnoth/blob/master/src/ai/default/attack.cpp , https://wiki.wesnoth.org/RCA_AI , https://wiki.wesnoth.org/LuaAPI/ai -> ý dồn đòn giết + đòn kết bằng quân rẻ.
- Portfolio Greedy Search (Churchill & Buro 2013, StarCraft combat): sinh nước bằng vài script thay vì vét mọi tổ hợp, chấm bằng playout — https://www.cs.mun.ca/~dchurchill/publications/pdf/combat13.pdf -> portfolio = style knob + tiền tố giết + giữ thành, AI v1 làm playout.
- Online Evolution (Justesen, Mahlmann, Togelius 2016; Justesen et al. 2018, Hero Academy, game nhiều hành động / lượt): tìm trên cả lượt, chấm bằng hàm đánh giá state, thắng MCTS vì nhánh quá rộng — https://core.ac.uk/download/84859342.pdf , https://njustesen.github.io/njustesen/publications/justesen2017playing.pdf -> lập kế hoạch cả lượt, không từng quân.
- Advance Wars / tactics: dồn hỏa lực tăng sức mạnh bậc 2, lính máu thấp đánh yếu (AE2 cũng vậy: sát thương × máu / 100) -> giết hẳn 1 quân > rải đòn. Đánh trước thắng thế.
- Hướng dẫn chiến thuật riêng cho Ancient Empires II: tìm không ra nguồn dùng được (kết quả toàn Age of Empires) -> dựa luật gốc đã xác minh bằng bytecode (`docs/review/ae2_research.md`).

### Đo trong lúc làm (seed dev salt 100–305, 144 ván / thử, điểm v2 vs Khó v1)
| Thử | Điểm |
|---|---|
| chỉ 6 style | 0,680 |
| + dồn đòn giết (6 style) | 0,816 |
| 3 style (nhanh hơn) / 5 mục tiêu giết / 3 ply / thu nhập ×8 + thành 600 | 0,826 / 0,795 / 0,812 / 0,833 (= nhiễu) |
| địch đáp thêm bằng dồn đòn giết / roll đáp 0,7 / thưởng tướng sống 800 | 0,785 / 0,802 / 0,812 (không lợi) |
| + "tướng về ô an toàn" + giữ thành (bản lỗi) | 0,663 / 0,694 (**tệ**: ứng viên thụ động mà hàm điểm lại thích) |
| **máu tướng rẻ (`pl_hp_cap` 200)** | **0,875** (cùng seed: 0,812 -> 0,875); 100: 0,854 |
| + phạt nguy cơ chết của tướng (threat map) | 0,826 (lại thụ động) |
| + giữ thành (đã sửa: thành có quân ta tính theo khoảng cách) | 0,882; seed khác 0,920 |

- Bài học: nút thắt là **hàm điểm**, không phải độ rộng tìm kiếm. Tính đủ giá 900 cho máu tướng -> mọi ứng viên "tướng nấp" thắng điểm -> chơi thụ động -> thua. Giống v1 (`hp_cap`): máu rẻ, giá trị lớn chỉ khi chết.
- Mọi trận thua đều có tướng ta chết (log `log=1`), tướng địch gần như không chết.
- `evolve` (`tune.gd`) không đột biến knob `pl_*` (chúng nằm ở `AIPlan.DEFAULT`, không ở `AI.DEFAULT`).

### Kết quả (seed giữ riêng salt 9000100–9000105, 66 ván / map / ghế -> 396 ván / cặp, cả 2 ghế, 3 map)
- **Khó v2 vs Khó v1: 0,896** (±0,015 SE; 355 thắng / 41 thua). Theo map (v2 ghế p / e): đồng bằng 65/66 – 65/66, cửa biển 49/66 – 55/66, núi rừng 59/66 – 62/66.
- Ma trận (điểm hàng vs cột, thắng 1 hòa 0,5, 396 ván / ô, cùng bộ seed; chạy song song `match` 6 tiến trình × `games=11`, salt 9000100–105):

| | Dễ | Thường | Khó v1 | Khó v2 |
|---|---|---|---|---|
| Dễ | – | 0,255 | 0,232 | 0,081 |
| Thường | 0,745 | – | 0,477 | 0,107 |
| Khó v1 | 0,768 | 0,523 | – | 0,104 |
| **Khó v2** | **0,919** | **0,893** | **0,896** | – |

- Thời gian (`tune.gd -- time a=hard_v2 b=hard_v1 games=4 salt=9100000`, 24 ván, Mac 10 nhân, máy đang tải ~5,7): mỗi bước TB 22 ms, p95 170 ms, tệ nhất 877 ms; **mỗi lượt TB 202 ms, p95 529 ms, tệ nhất 1,19 s**. Khó v1 cùng seed: bước 2,5 ms, lượt TB 16 ms / tệ nhất 46 ms. `AIPlan.last.capped` không bật lần nào (phanh 4 s). Điện thoại chậm ~3–5× -> lượt TB ~0,6–1 s, tệ nhất có thể 3–6 s: cần đo máy thật; giảm `pl_kill` / `pl_replan` nếu chậm (đổi lực, phải đo lại).
- Sim chậm hơn: ~0,25 ván/s mỗi tiến trình khi có v2 (v1–v1 ~0,7).

### Ví dụ (`sim/probes/plan_probe.gd -- games=1`, seed salt 9200000)
- Đồng bằng lượt 15 (v2 = p): tướng địch 45 máu ở (12,1). v1: tướng ta chiếm thành, 3 lính đánh tướng địch -> roll giữa còn sống. v2: tướng ta đánh trước rồi 2 lính kết -> **giết tướng địch** (dư 1 lính đi đánh lính khác).
- Cửa biển lượt 16 (v2 = e): tướng ta 64 máu. v1: cung #18 đi chỗ khác, 5 quân đánh -> tướng sống (roll giữa). v2: **6 đòn dồn**, cung / thuyền (không bị phản đòn hoặc phản yếu) trước -> tướng chết.
- Cửa biển lượt 6 (v2 = p): tướng địch đứng sát thành ta (8,7). v1 cho lính trên thành đi chỗ khác -> thành trống. v2 đưa cung vào đứng thành (điểm 2 ply thấy tướng địch chiếm thành ở lượt đáp).
- Thống kê 1 lượt chạy (80 lượt v2): lần lập đầu lượt chọn style 58 lần, dồn đòn giết 28 lần; lập lại giữa lượt 10 lần (roll thật khác dự đoán).

## Độ khó (phác thảo, chưa nối vào game)
Cho chế độ 1v1 sau này (người vs người tại chỗ, hoặc người vs AI Dễ / Thường / Khó). Nối: lúc tạo ván, `s.aiParams = { "e": PRESET }` (lưu cùng ván -> nạp lại vẫn đúng mức).

| Mức | Params | Ghi chú |
|---|---|---|
| Dễ | `noise` 60, `caution` 0, `caution_hero` 0.3, `home_hp` 0, `heal_hp` 0, `maydie_w` 0.1 | liều: không sợ chết, không về hồi máu, chọn nước thô |
| Dễ + ½ vàng | Dễ + vàng đầu ván ×0.5 (`skirmish_def(..., easy=true)` đã có cho phe e) | chấp thêm |
| Thường | `DEFAULT` | AI hiện tại |
| Khó (v1, tới 2026-11-06) | `sim/tuned_params.txt` (`noise` giữ 8) | tham số tự đấu. Bản ít nhiễu (`noise` 2, `hard_n2`) đo ra **yếu hơn** Thường -> bỏ. Nay Khó = v2 (mục "Khó v2" ở trên) |

Đo (`sim/tune.gd -- presets games=8`, 4 bộ seed salt 9000000/10/20/30, 192 ván / cặp; điểm hàng vs cột, thắng 1 hòa 0,5):

| | Dễ+½ vàng | Dễ | Thường | Khó | Khó noise 2 |
|---|---|---|---|---|---|
| Dễ+½ vàng | – | 0,318 | 0,125 | 0,146 | 0,120 |
| Dễ | 0,682 | – | 0,326 | 0,234 | 0,260 |
| Thường | 0,875 | 0,674 | – | 0,448 | 0,542 |
| Khó | 0,854 | 0,766 | 0,552 | – | 0,539 |
| Khó noise 2 | 0,880 | 0,740 | 0,458 | 0,461 | – |

- Thứ tự đúng: Dễ+½ vàng < Dễ < Thường < Khó. Khó vs Thường 0,552 (riêng 3 bộ seed không dùng để chọn đảo: 0,549).
- Khoảng cách Thường–Khó nhỏ (~55%): muốn Khó rõ hơn -> tune lâu hơn / nhiều ván hơn mỗi thế hệ, hoặc cho Khó thêm vàng.
- Dễ còn thắng Thường ~1/3 (AI-vs-AI); với người thật, Dễ nên thử chơi trước khi chốt số.
