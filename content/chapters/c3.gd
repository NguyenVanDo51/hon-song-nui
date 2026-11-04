extends RefCounted
## chapter 3: Bà Triệu's uprising against Eastern Wu (248). Enemy skin switches from Hán to Ngô. Format: content/chapters/c1.gd

const DEF := {
	"id": "c3", "order": 3,
	"title": "Bà Triệu",
	"years": "Năm 248",
	"subtitle": "Năm 248 · Cửu Chân dưới ách nhà Đông Ngô",
	"blurb": "Từ núi Nưa, Bà Triệu cùng anh là Triệu Quốc Đạt khởi binh, cưỡi voi đánh quân Ngô.",
	"note": "Sơ đồ phỏng theo, không đúng tỉ lệ. Cửu Chân nay là vùng Thanh Hóa.",
	"rivers": [
		{ "name": "Sông Mã", "w": 3.0, "d": "M0,14 C14,18 24,24 34,32 S50,44 60,50 S76,60 86,64 S96,68 100,70" },
		{ "name": "Sông Chu", "w": 2, "d": "M8,58 C20,56 30,58 40,56 S54,52 60,50" },
		{ "name": "Sông Lèn", "w": 1.4, "d": "M40,30 C46,24 54,20 62,18 S74,14 80,10" },
	],
	"lakes": [{ "name": "Biển", "cx": 108, "cy": 40, "rx": 14, "ry": 36 }],
	"labels": [
		{ "text": "CỬU CHÂN", "x": 30, "y": 66, "size": 4 },
		{ "text": "Sông Mã", "x": 74, "y": 66, "size": 2.2, "river": true },
		{ "text": "Sông Chu", "x": 16, "y": 54, "size": 2, "river": true },
		{ "text": "Núi Nưa", "x": 24, "y": 30, "size": 2.4 },
	],
	"theme": {
		"text": { "enemyTurn": "Lượt quân Ngô" },
		"factions": {
			"e": { "name": "Quân Đông Ngô", "short": "Quân Ngô", "body": "#1d3b35", "body2": "#2e5c52", "ring": "#d8c27a", "glow": "#a8e8cf", "roof": "#2e5c52" },
		},
		"units": {
			"e": {
				"soldier": { "name": "Bộ binh Ngô", "icon": "🔱", "desc": "Lính Ngô cầm giáo. Rẻ, chiếm được làng." },
				"archer": { "name": "Cung thủ Ngô", "icon": "🏹", "desc": "Bắn xa 1–2 ô. +20 công khi bắn kỵ binh." },
				"bird": { "name": "Kỵ binh Ngô", "icon": "🐎", "desc": "Ngựa Ngô: mọi ô chỉ tốn 1. Chạy trống trải nên không được địa hình che." },
				"elephant": { "name": "Giáp sĩ Ngô", "icon": "🛡️", "desc": "Lính giáp sắt nặng. Thủ dày, đánh mạnh, đi chậm, không lên được núi." },
			},
		},
	},
	"outro": [
		["truyenthuyet", "Bà Triệu hy sinh trên núi Tùng năm 248, khi mới hai mươi ba tuổi. Đền thờ Bà ở Hậu Lộc, Thanh Hóa, khói hương chưa bao giờ tắt."],
		["batrieu", "Tôi muốn cưỡi cơn gió mạnh, đạp luồng sóng dữ, chém cá kình ở Biển Đông, đánh đuổi quân Ngô, giành lại giang sơn, cởi ách nô lệ."],
	],
}
