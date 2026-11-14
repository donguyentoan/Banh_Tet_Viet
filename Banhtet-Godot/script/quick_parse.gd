class_name QuickParse
extends RefCounted

## Phân tích tin nhắn đặt bánh theo cú pháp tự do.
## Chuyển từ src/lib/quick-parse.ts.

const SPOKEN_NUMBERS: Dictionary = {
	"mot": 1, "hai": 2, "ba": 3, "bon": 4, "tu": 4,
	"nam": 5, "sau": 6, "bay": 7, "tam": 8, "chin": 9, "muoi": 10,
}

## Từ bỏ nhiễu trong tin nhắn, không phải tên khách
const NOISE_WORDS: Array[String] = [
	"ngay", "giao", "luc", "nhe", "nho", "cam on", "chao", "ban",
	"minh", "vs", "va", "cho", "them", "a", "ban", "dat", "don",
]


## Chuẩn hoá chuỗi: bỏ dấu, lowercase
##
## Godot không có sẵn Unicode NFD, nên ta dùng bảng thay thế tường minh cho
## các chữ tiếng Việt có dấu (dạng dựng sẵn, ví dụ "ệ" = U+1EC7).
static func normalize_text(text: String) -> String:
	var result := text.to_lower()
	for pair in DIACRITIC_REPLACEMENTS:
		result = result.replace(pair[0], pair[1])
	return result.strip_edges()


## Cặp (ký tự có dấu, ký tự không dấu)
const DIACRITIC_REPLACEMENTS: Array = [
	["à", "a"], ["á", "a"], ["ả", "a"], ["ã", "a"], ["ạ", "a"],
	["â", "a"], ["ấ", "a"], ["ầ", "a"], ["ẩ", "a"], ["ẫ", "a"], ["ậ", "a"],
	["ă", "a"], ["ắ", "a"], ["ằ", "a"], ["ẳ", "a"], ["ẵ", "a"], ["ặ", "a"],
	["è", "e"], ["é", "e"], ["ẻ", "e"], ["ẽ", "e"], ["ẹ", "e"],
	["ê", "e"], ["ế", "e"], ["ề", "e"], ["ể", "e"], ["ễ", "e"], ["ệ", "e"],
	["ì", "i"], ["í", "i"], ["ỉ", "i"], ["ĩ", "i"], ["ị", "i"], ["î", "i"],
	["ò", "o"], ["ó", "o"], ["ỏ", "o"], ["õ", "o"], ["ọ", "o"],
	["ô", "o"], ["ố", "o"], ["ồ", "o"], ["ổ", "o"], ["ỗ", "o"], ["ộ", "o"],
	["ơ", "o"], ["ớ", "o"], ["ờ", "o"], ["ở", "o"], ["ỡ", "o"], ["ợ", "o"],
	["ù", "u"], ["ú", "u"], ["ủ", "u"], ["ũ", "u"], ["ụ", "u"],
	["ư", "u"], ["ứ", "u"], ["ừ", "u"], ["ử", "u"], ["ữ", "u"], ["ự", "u"],
	["ỳ", "y"], ["ý", "y"], ["ỷ", "y"], ["ỹ", "y"], ["ỵ", "y"],
	["đ", "d"],
]


## Chuẩn hoá mã bánh: bỏ dấu, uppercase, bỏ khoảng trắng
static func normalize_code(code: String) -> String:
	return normalize_text(code).replace(" ", "").replace("\t", "")


## Tạo bảng tra mã bánh từ danh mục sản phẩm
static func build_code_index(products: Array) -> Dictionary:
	var index := {}

	for product in products:
		var code = product.get("code", null)
		if code != null and not str(code).is_empty():
			index[normalize_code(str(code))] = product

	for product in products:
		var name := normalize_text(str(product.get("name", "")))
		var candidates: Array[String] = []

		if name.find("chung") != -1:
			var is_large := name.find("lon") != -1
			if name.find("chay") != -1:
				candidates.append("ccl" if is_large else "cc")
			else:
				candidates.append("cml" if is_large else "cm")

		if name.find("tet") != -1:
			if name.find("ngot") != -1:
				candidates.append("tn")
			elif name.find("chay") != -1:
				candidates.append("tc")
			else:
				candidates.append("tt")

		for code in candidates:
			if not index.has(code):
				index[code] = product

	return index


## Chuẩn hoá ngày giao từ nhiều định dạng -> ISO (YYYY-MM-DD) hoặc rỗng
static func parse_delivery_date(input: String) -> String:
	var text := input.strip_edges()
	if text.is_empty():
		return ""

	# 26-29 Tết
	var lunar := _match_lunar(text)
	if lunar != "":
		return lunar

	# Dạng 03/02/2027 hoặc 03/02
	var slash := _match_slash_date(text)
	if slash != "":
		return slash

	return ""


static func _match_lunar(text: String) -> String:
	var regex := _regex("(2[6-9])\\s*t[eế]t", true)
	var result := regex.search(text)
	if result == null:
		return ""
	var lunar_day := int(result.get_string(1))
	for suggestion in BanhTet.DELIVERY_DATE_SUGGESTIONS:
		if str(suggestion["short"]).begins_with("%d Tết" % lunar_day):
			return str(suggestion["value"])
	return ""


static func _match_slash_date(text: String) -> String:
	var regex := _regex("(\\d{1,2})[/.-](\\d{1,2})(?:[/.-](\\d{2,4}))?")
	var result := regex.search(text)
	if result == null:
		return ""
	var day := int(result.get_string(1))
	var month := int(result.get_string(2))
	var year := 2027
	if result.get_string(3) != "":
		year = int(result.get_string(3))
	if year < 100:
		year += 2000
	if month >= 1 and month <= 12 and day >= 1 and day <= 31:
		return "%d-%02d-%02d" % [year, month, day]
	return ""


## Chuẩn hoá khung giờ giao từ text tự do
static func parse_delivery_time(input: String) -> String:
	var text := normalize_text(input)

	# Tìm giờ: "8 gio sang", "8h", "8:30", "8"
	var hour := -1
	var hour_regex := _regex("\\b(\\d{1,2})\\b")
	var hour_match := hour_regex.search(text)
	if hour_match != null:
		hour = int(hour_match.get_string(1))
		if hour > 12 and hour <= 23:
			hour -= 12

	# Tìm buổi
	var period := ""
	for key in ["sang", "chieu", "toi", "trua", "dem"]:
		if text.find(key) != -1:
			period = key
			break

	if hour >= 1 and hour <= 12 and period != "":
		match period:
			"sang":
				return "Sáng (%02d:00 - 11:00)" % hour
			"chieu":
				return "Chiều (13:00 - %02d:00)" % (hour + 4)
			"toi":
				return "Tối (%02d:00 - 21:00)" % (hour + 12)
			"trua":
				return "Buổi trưa (11:00 - 13:00)"
			"dem":
				return "Buổi tối (21:00 - 23:00)"

	if period != "":
		match period:
			"sang":
				return "Sáng (07:00 - 11:00)"
			"chieu":
				return "Chiều (13:00 - 17:00)"
			"toi":
				return "Tối (18:00 - 21:00)"
			"trua":
				return "Buổi trưa (11:00 - 13:00)"
			"dem":
				return "Buổi tối (21:00 - 23:00)"

	return ""


## Lấy phần cuối chuỗi gốc tương ứng với đuôi đã chuẩn hoá.
## Dùng để trả về địa chỉ còn dấu tiếng Việt.
static func _extract_original_tail(original: String, normalized_tail: String) -> String:
	var tail_length := normalized_tail.length()
	if tail_length <= 0 or tail_length > original.length():
		return ""
	return original.substr(original.length() - tail_length, tail_length).strip_edges()


## Tìm số điện thoại trong text
static func parse_phone(input: String) -> String:
	var regex := _regex("(\\+84|0)\\d{9,10}")
	var result := regex.search(input)
	return result.get_string() if result != null else ""


## Tìm địa chỉ trong text (sau các từ khoá chỉ bố trí)
static func _parse_address(input: String) -> String:
	# Match trên bản đã bỏ dấu để "địa chỉ" -> "dia chi"
	var normalized := normalize_text(input)
	# Từ khoá chỉ bố trí địa chỉ, xếp theo độ dài giảm dần để tránh khớp nhầm
	var keywords: Array[String] = ["dia chi", "o tai", "dc", "gia", "tai", "o"]
	for keyword in keywords:
		var regex := _regex(
			"(?<![a-z0-9])(?:" + escape_regex(keyword) + ")\\s*[:-]?\\s*(.+)$",
			true
		)
		var result := regex.search(normalized)
		if result != null:
			var value := result.get_string(1).strip_edges()
			if not value.is_empty():
				# Trả về bản gốc (giữ dấu tiếng Việt)
				return _extract_original_tail(input, value)
	return ""


## Escape regex special chars
static func escape_regex(text: String) -> String:
	return text.replace(".", "\\.").replace("*", "\\*").replace("+", "\\+") \
		.replace("?", "\\?").replace("^", "\\^").replace("$", "\\$") \
		.replace("(", "\\(").replace(")", "\\)").replace("[", "\\[") \
		.replace("]", "\\]").replace("{", "\\{").replace("}", "\\}") \
		.replace("|", "\\|").replace("/", "\\/")


## Tạo RegEx đã biên dịch. `ignore_case` sẽ thêm cờ (?i) vào pattern.
static func _regex(pattern: String, ignore_case: bool = false) -> RegEx:
	var regex := RegEx.new()
	var final_pattern := pattern
	if ignore_case:
		final_pattern = "(?i)" + pattern
	regex.compile(final_pattern)
	return regex


## Chuyển mã chuẩn hoá thành pattern regex (hỗ trợ cả "Đ")
static func _code_to_pattern(code: String) -> String:
	return escape_regex(code).replace("d", "[dđ]").replace("D", "[DĐ]")


## Alias gọi tự nhiên cho từng sản phẩm
static func _voice_aliases(product: Dictionary) -> Array[String]:
	var name := normalize_text(str(product.get("name", "")))
	var category := str(product.get("category", ""))

	if category == "CHUNG":
		var is_large := name.find("lon") != -1
		if name.find("chay") != -1:
			if is_large:
				return ["bánh chưng chay lớn", "chưng chay lớn", "bánh chưng lớn chay"]
			return ["bánh chưng chay", "chưng chay"]
		if is_large:
			return ["bánh chưng thịt lớn", "chưng thịt lớn", "bánh chưng mặn lớn", "chưng mặn lớn"]
		return ["bánh chưng mặn", "chưng mặn", "bánh chưng thịt", "chưng thịt"]

	if name.find("ngot") != -1:
		return ["bánh tét nhân ngọt", "bánh tét ngọt", "tét ngọt", "nhân ngọt"]
	if name.find("chay") != -1:
		return ["bánh tét chay", "tét chay"]
	return ["bánh tét thịt", "tét thịt", "bánh tét mặn", "tét mặn"]


static func _parse_spoken_number(value: String) -> int:
	var numeric := int(value)
	if numeric != 0:
		return numeric
	return int(SPOKEN_NUMBERS.get(normalize_text(value), 0))


## Tìm số lượng trong một đoạn text ngắn.
## `look_behind` = true  -> lấy số ở CUỐI đoạn (số đứng trước tên bánh).
## `look_behind` = false -> lấy số ở ĐẦU đoạn (số đứng sau tên bánh).
static func _find_number(text: String, look_behind: bool) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return 0

	# Số đứng trước alias: tìm token số cuối cùng trong đoạn
	if look_behind:
		var tokens := trimmed.replace("/", " ").replace(",", " ").split(" ", false)
		for i in range(tokens.size() - 1, -1, -1):
			var token := str(tokens[i]).strip_edges()
			if token.is_empty():
				continue
			var value := _parse_spoken_number(token)
			if value > 0:
				return value
			# Token không phải số -> dừng (số lượng phải sát alias)
			if token.to_int() > 0:
				return 0
			return 0
		return 0

	# Số đứng sau alias: tìm token số đầu tiên trong đoạn
	var tokens2 := trimmed.replace("/", " ").replace(",", " ").split(" ", false)
	for token in tokens2:
		var token_text := str(token).strip_edges()
		if token_text.is_empty():
			continue
		var value2 := _parse_spoken_number(token_text)
		if value2 > 0:
			return value2
		return 0
	return 0


## Phân tích tin nhắn đặt bánh
static func parse_quick_order(raw_text: String, products: Array) -> Dictionary:
	var text := raw_text.strip_edges()
	var code_index := build_code_index(products)

	var quantities := {}
	var unknown_codes: Array[String] = []
	var matched_codes: Array[String] = []

	var known_codes: Array[String] = []
	for key in code_index.keys():
		known_codes.append(str(key))
	known_codes.sort_custom(func(a, b): return a.length() > b.length())

	if known_codes.size() > 0:
		var alternation := ""
		for i in range(known_codes.size()):
			if i > 0:
				alternation += "|"
			alternation += _code_to_pattern(known_codes[i])
		var pair_pattern := _regex(
			"(\\d{1,4})\\s*(" + alternation + ")\\b|\\b(" + alternation + ")\\s*(\\d{1,4})\\b",
			true
		)
		for match in pair_pattern.search_all(text):
			var raw_code := (match.get_string(2) if match.get_string(2) != "" else match.get_string(3)).strip_edges()
			var raw_qty := match.get_string(1) if match.get_string(1) != "" else match.get_string(4)
			var quantity := int(raw_qty)
			if raw_code.is_empty() or quantity <= 0:
				continue
			var code := normalize_code(raw_code)
			if not code_index.has(code):
				continue
			var product = code_index[code]
			var product_id := str(product.get("id", ""))
			quantities[product_id] = int(quantities.get(product_id, 0)) + quantity
			var label := str(product.get("code", code))
			if not matched_codes.has(label):
				matched_codes.append(label)

	#
	# Chiến lược: KHÔNG dựng 1 regex khổng lồ (gây backtracking thừa trong
	# Godot). Thay vào đó:
	#   - Bước 1: tìm vị trí các ALIAS trong text (mỗi alias 1 regex riêng,
	#     lấy kết quả dài nhất khi trùng vị trí).
	#   - Bước 2: với mỗi alias đã tìm được, tìm số lượng ngay TRƯỚC hoặc
	#     SAU alias (trong vùng liền kề).
	var normalized_text := normalize_text(text)

	# Gom alias -> sản phẩm, ưu tiên alias dài hơn
	var alias_to_product := {}
	var alias_list: Array[String] = []
	for product in products:
		for alias in _voice_aliases(product):
			var normalized_alias := normalize_text(alias)
			if normalized_alias.is_empty():
				continue
			if alias_to_product.has(normalized_alias):
				continue
			alias_to_product[normalized_alias] = product
			alias_list.append(normalized_alias)
	alias_list.sort_custom(func(a, b): return a.length() > b.length())

	# Vị trí -> (alias, sản phẩm). Giữ alias dài nhất tại mỗi vị trí.
	var hits := {}  # start_index -> {"alias": String, "length": int, "product": Dictionary}

	for alias in alias_list:
		var alias_regex := _regex(escape_regex(alias))
		for match in alias_regex.search_all(normalized_text):
			var start: int = match.get_start()
			# Lưu ý: không dùng `match.get_length()` - hàm này treo trong
			# Godot 4.3 headless. Tính độ dài từ get_end() - get_start().
			var length: int = match.get_end() - start
			# Bỏ qua alias nằm trong một alias dài hơn đã khớp tại cùng vị trí
			var existing = hits.get(start, null)
			if existing != null and int(existing["length"]) >= length:
				continue
			hits[start] = {
				"alias": alias,
				"length": length,
				"product": alias_to_product[alias],
			}

	# Sắp xếp theo vị trí
	var hit_starts: Array = hits.keys()
	hit_starts.sort()

	for start_var in hit_starts:
		var start: int = int(start_var)
		var hit = hits[start]
		var end: int = start + int(hit["length"])

		# Bỏ qua nếu alias này nằm TRỌN VẸN trong một alias khác dài hơn
		# (VD: "chung man" nằm trong "banh chung man" -> bỏ alias ngắn).
		var inside_other := false
		for other_start_var in hit_starts:
			var other_start: int = int(other_start_var)
			if other_start == start:
				continue
			var other = hits[other_start]
			var other_end: int = other_start + int(other["length"])
			# Chỉ bỏ khi alias này nằm trọn trong alias kia VÀ alias kia dài hơn
			if other_start <= start and end <= other_end and other_end - other_start > end - start:
				inside_other = true
				break
		if inside_other:
			continue

		# Tìm số lượng: ưu tiên số NGAY TRƯỚC alias, sau đó số NGAY SAU
		var quantity := 0
		var before_text := normalized_text.substr(maxi(0, start - 24), maxi(0, start - maxi(0, start - 24)))
		var after_text := normalized_text.substr(end, 24)

		var before_num := _find_number(before_text, true)
		var after_num := _find_number(after_text, false)

		if before_num > 0:
			quantity = before_num
		elif after_num > 0:
			quantity = after_num

		if quantity <= 0:
			continue

		var product = hit["product"]
		var product_id := str(product.get("id", ""))
		quantities[product_id] = int(quantities.get(product_id, 0)) + quantity

		var label := str(product.get("code", product_id))
		if not matched_codes.has(label):
			matched_codes.append(label)

	# 2) Tìm mã lạ
	var unknown_pattern := _regex("(\\d{1,4})\\s+([A-ZĐ]{2,4})\\b|\\b([A-ZĐ]{2,4})\\s+(\\d{1,4})\\b")
	for match in unknown_pattern.search_all(text):
		var raw_code := (match.get_string(2) if match.get_string(2) != "" else match.get_string(3)).strip_edges()
		if raw_code.is_empty():
			continue
		if code_index.has(normalize_code(raw_code)):
			continue
		if not unknown_codes.has(raw_code):
			unknown_codes.append(raw_code)

	# 3) Ngày giao
	var delivery_date := BanhTet.DEFAULT_DELIVERY_DATE
	var date_match := _search_date(text)
	if date_match != "":
		var parsed := parse_delivery_date(date_match)
		if parsed != "":
			delivery_date = parsed

	# 4) Khung giờ
	var delivery_time := BanhTet.DEFAULT_DELIVERY_TIME
	var time_match := _search_time(text)
	if time_match != "":
		var parsed_time := parse_delivery_time(time_match)
		if parsed_time != "":
			delivery_time = parsed_time

	# 5) SĐT
	var phone := parse_phone(text)

	# 6) Địa chỉ
	var address := _parse_address(text)

	# 7) Tên khách
	# Chiến lược (làm trên bản chuẩn hoá đã bỏ dấu):
	#   a) Cắt phần địa chỉ: mọi thứ từ từ khoá địa chỉ trở đi bị bỏ.
	#   b) Xoá mã bánh, cụm "<số> + <tên bánh tự nhiên>", SĐT, ngày, giờ,
	#      và các từ bỏ nhiễu.
	#   c) Lấy đoạn dài nhất còn lại làm tên khách, rồi ánh xạ ngược về
	#      bản gốc để giữ nguyên dấu tiếng Việt.
	var name_source := _strip_address_tail_normalized(normalized_text)

	if known_codes.size() > 0:
		var alternation := ""
		for i in range(known_codes.size()):
			if i > 0:
				alternation += "|"
			alternation += _code_to_pattern(known_codes[i])
		var strip_pattern := _regex(
			"\\b\\d{1,4}\\s*(?:" + alternation + ")\\b|\\b(?:" + alternation + ")\\s*\\d{1,4}\\b",
			true
		)
		name_source = strip_pattern.sub(name_source, " ", true)

	# Xoá cụm "<số lượng> + <tên bánh tự nhiên>" khỏi phần tên khách.
	# Dùng chung alias_list đã gom ở trên (đã sắp xếp dài -> ngắn).
	if alias_list.size() > 0:
		var alias_pattern := ""
		for i in range(alias_list.size()):
			if i > 0:
				alias_pattern += "|"
			alias_pattern += escape_regex(alias_list[i])
		var spoken_name_pattern := _regex(
			"(?:\\b\\d{1,3}|\\b(?:mot|hai|ba|bon|tu|nam|sau|bay|tam|chin|muoi))"
			+ "\\s*(?:(?:cai|chiec)\\s+)?(?:" + alias_pattern + ")\\b"
			+ "|(?:" + alias_pattern + ")\\s+(?:\\d{1,3}|mot|hai|ba|bon|tu|nam|sau|bay|tam|chin|muoi)\\b",
			true
		)
		name_source = spoken_name_pattern.sub(name_source, " ", true)

	name_source = _cleanup_name_text(name_source)

	# Chọn đoạn dài nhất còn lại, sau đó ánh xạ về bản gốc (giữ dấu).
	var best := ""
	for part in name_source.split("  ", false):
		var cleaned := _collapse_spaces(part)
		if cleaned.length() >= 2 and cleaned.length() > best.length():
			best = cleaned

	var customer_name := _map_to_original(text, best)

	return {
		"customerName": customer_name,
		"phone": phone,
		"address": address,
		"deliveryDate": delivery_date,
		"deliveryTime": delivery_time,
		"quantities": quantities,
		"unknownCodes": unknown_codes,
		"matchedCodes": matched_codes,
	}


static func _collapse_spaces(text: String) -> String:
	var result := ""
	var last_space := true
	for i in range(text.length()):
		var c := text[i]
		if c == " " or c == "\t" or c == "\n":
			if not last_space:
				result += " "
			last_space = true
		else:
			result += c
			last_space = false
	return result.strip_edges()


## Cắt phần địa chỉ khỏi text đã chuẩn hoá: mọi thứ từ từ khoá địa chỉ
## trở đi bị bỏ. Chạy trên bản đã bỏ dấu nên không lệch chỉ số.
static func _strip_address_tail_normalized(text: String) -> String:
	var keywords: Array[String] = ["dia chi", "o tai", "dc", "gia"]
	for keyword in keywords:
		var regex := _regex("(?:" + escape_regex(keyword) + ")\\s*[:-]?", true)
		var result := regex.search(text)
		if result != null:
			var cut := result.get_start()
			if cut > 0:
				return text.substr(0, cut).strip_edges()
	return text


## Ánh xạ một đoạn đã bỏ dấu về lại vị trí tương ứng trong chuỗi gốc
## (giữ nguyên dấu tiếng Việt).
##
## Bảng thay thế bỏ dấu giữ nguyên độ dài chuỗi, nên vị trí ký tự tương
## ứng trực tiếp giữa bản gốc và bản đã bỏ dấu (sau khi lowercase).
static func _map_to_original(original: String, normalized_fragment: String) -> String:
	if normalized_fragment.is_empty():
		return ""

	var original_lower := original.to_lower()
	var normalized_original := normalize_text(original)

	var start := normalized_original.find(normalized_fragment)
	if start == -1:
		# Thử tìm bằng so khớp tiền tố/suffix dấu cách nhau
		var words := normalized_fragment.split(" ", false)
		if words.is_empty():
			return normalized_fragment
		start = normalized_original.find(words[0])
		if start == -1:
			return normalized_fragment

	var length := normalized_fragment.length()
	if start + length > original_lower.length():
		length = original_lower.length() - start
	# Lấy từ bản GỐC (giữ hoa/thường và dấu), vị trí đã khớp với bản
	# chuẩn hoá nên độ dài tương ứng.
	return original.substr(start, length).strip_edges()


## Dọn dẹp chuỗi để lấy ra tên khách: bỏ SĐT, ngày, giờ, từ bỏ nhiễu.
## Chuỗi đầu vào nên đã được chuẩn hoá (bỏ dấu).
static func _cleanup_name_text(text: String) -> String:
	var result := text

	var cleanup_patterns: Array = [
		{"pattern": "(\\+84|0)\\d{9,10}", "ic": false},
		{"pattern": "\\d{1,2}[/.-]\\d{1,2}(?:[/.-]\\d{2,4})?", "ic": false},
		{"pattern": "\\b(2[6-9])\\s*tet\\b", "ic": true},
		{"pattern": "\\bngay\\b", "ic": true},
		{"pattern": "\\d{1,2}\\s*(?:h|gio)\\s*(?:sang|chieu|toi|trua|dem)?", "ic": true},
		{"pattern": "\\b(sang|chieu|toi|trua|dem)\\b", "ic": true},
		{"pattern": "\\b(dia chi|dc|o tai|gia)\\b\\s*[:-]?\\s*", "ic": true},
	]
	for entry in cleanup_patterns:
		var cleanup := _regex(str(entry["pattern"]), bool(entry["ic"]))
		result = cleanup.sub(result, " ", true)

	result = result.replace("/", " ").replace("|", " ").replace(",", " ")

	for word in NOISE_WORDS:
		var word_pattern := _regex("\\b" + escape_regex(word) + "\\b", true)
		result = word_pattern.sub(result, " ", true)

	return result


## Tìm chuỗi ngày giao trong text (dạng d/l/m hoặc "27 Tết")
static func _search_date(text: String) -> String:
	var regex := _regex("\\d{1,2}[/.-]\\d{1,2}(?:[/.-]\\d{2,4})?")
	var result := regex.search(text)
	if result != null:
		return result.get_string()
	regex = _regex("\\b(2[6-9])\\s*t[eế]t", true)
	result = regex.search(text)
	return result.get_string() if result != null else ""


## Tìm chuỗi khung giờ giao trong text ("8 gio sang", "chiều", ...)
static func _search_time(text: String) -> String:
	# Chuẩn hoá trước để "chiều" -> "chieu", "8 giờ" -> "8 gio" khớp regex.
	var normalized := normalize_text(text)
	var regex := _regex(
		"\\d{1,2}\\s*(?:h|gio)\\s*(?:sang|chieu|toi|trua|dem)?"
		+ "|\\b(sang|chieu|toi|trua|dem)\\b",
		true
	)
	var result := regex.search(normalized)
	return result.get_string() if result != null else ""


