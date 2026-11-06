# Hồn Sông Núi — spec v1

Chiến thuật theo lượt trên lưới ô, bối cảnh dân gian Việt. Ta (Văn Lang) vs Thủy Tinh + thủy quái.
Luật = luật chung của thể loại; tên / bản đồ / lính / chỉ số / hình = tự làm.

## Luật
- Lưới 14×11, 1 bản đồ đối xứng xoay 180°. Ta: thành dưới-trái. Địch: thành trên-phải. 2 thành trung lập, 14 làng trung lập.
- Lượt: chọn lính -> đi (không xuyên quân địch, xuyên quân mình OK) -> hành động: Đánh / Chiếm / Gọi hồn / Chờ.
- Đầu lượt: +50 vàng/làng, +100/thành. Lính đứng trên làng/thành của mình +20 máu.
- Mua lính (AE2, `RULES.buyAE2`): bấm thành mình -> lính ra, đi + đánh ngay lượt đó. Thành có quân ta: chọn quân đó -> "Mộ quân"; lính mới đứng chồng, phải bước ra (không đứng yên, không hết lượt được tới khi ra); tối đa 2 quân / ô; hết ô trống để ra -> không mua được. Mua nhiều lần / thành / lượt. AI chỉ mua khi thành trống.
- Sát thương (cố định, xem trước được): `max(15%·A, A − D) × máu_người_đánh/100`
  - A = công + 5·cấp + trống đồng (+10) + nỏ đánh bay (+20)
  - D = thủ + 5·cấp + địa hình (bay = 0; thầy mo bỏ qua địa hình) + Lạc Long Quân (+10)
- Đánh trả: còn sống + người đánh nằm trong tầm + không phải máy bắn đá.
- Kinh nghiệm: = sát thương gây ra, hạ địch +50. Cấp 1/2/3 ở 100/250/450.
- Chết (trừ tướng, hồn) -> để lại mộ 2 vòng. Thầy mo đứng cạnh mộ -> Gọi hồn -> lính Hồn.
- Tướng chết -> mua lại ở thành (400 vàng).
- Thua: hết thành, hoặc hết lính + không đủ 150 vàng.

## Địa hình (thủ +, giá đi)
Đồng 0/1 · Rừng 10/2 · Đồi 15/2 · Núi 20/3 (voi, máy bắn đá không qua) · Sông —/không qua (bay, Lạc Long Quân, Thủy Tinh qua) · Cầu/Bãi cạn 0/1 · Làng 15/1 · Thành 20/1

## Lính (vai trò · giá · công/thủ/đi/tầm)
| Vai trò | Ta | Địch | Giá | C/T/Đi/Tầm |
|---|---|---|---|---|
| Cận chiến cơ bản, chiếm làng | Dân binh | Tôm binh | 150 | 50/10/4/1 |
| Bắn xa, khắc bay | Nỏ thủ | Ốc phun | 250 | 45/5/4/1-2 |
| Hỗ trợ: cạnh bên +10 công | Trống đồng | Tù và | 300 | 30/10/5/1 |
| Phép: bỏ qua địa hình, gọi hồn | Thầy mo | Phù thủy biển | 400 | 40/10/4/1-2 |
| Nặng | Voi chiến | Thuồng luồng | 500 | 65/25/3/1 |
| Bay, bỏ qua địa hình | Chim Lạc | Dơi quỷ | 600 | 60/15/7/1 |
| Công thành: không đi+bắn cùng lượt | Máy bắn đá | Rùa phóng đá | 700 | 70/5/3/2-4 |
| Gọi từ mộ | Hồn | Hồn | — | 40/5/4/1 |

## Tướng (chiếm làng + thành)
- Sơn Tinh 60/20/5: đi núi/đồi giá 1, đứng đồi/núi thêm +10 thủ.
- Thánh Gióng 70/15/6.
- Lạc Long Quân 60/20/5: đi sông, lính cạnh bên +10 thủ.
- Thủy Tinh (địch) 60/20/5: đi sông.

## Để sau (sau khi chơi thử)
Chiến dịch nhiều màn, sương mù, trạng thái (độc…), 2 người cùng máy, thủy triều.
