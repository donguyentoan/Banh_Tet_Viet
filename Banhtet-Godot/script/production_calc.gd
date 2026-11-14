class_name ProductionCalc
extends RefCounted

## Tính bảng cân đối kho bánh cho một ngày.
## Chuyển từ src/lib/production.ts.

## Tổng hợp số lượng bánh khách lẻ đặt trong ngày (bỏ qua đơn đã hủy)
static func sum_retail_demand(orders: Array, date: String) -> Dictionary:
	var result := {}
	for order in orders:
		if str(order.get("status", "")) == "Đã hủy":
			continue
		if str(order.get("deliveryDate", "")) != date:
			continue
		var items = order.get("items", {})
		for product_id in items:
			var qty := int(items[product_id])
			if qty <= 0:
				continue
			result[product_id] = int(result.get(product_id, 0)) + qty
	return result


## Tổng hợp số lượng bánh các mối chợ lấy trong ngày
static func sum_wholesale_demand(wholesale_list: Array, date: String) -> Dictionary:
	var result := {}
	for entry in wholesale_list:
		if str(entry.get("date", "")) != date:
			continue
		var items = entry.get("items", {})
		for product_id in items:
			var qty := int(items[product_id])
			if qty <= 0:
				continue
			result[product_id] = int(result.get(product_id, 0)) + qty
	return result


## Tồn kho gối đầu của ngày (dư từ ngày trước chuyển sang)
static func get_opening_stock(inventories: Array, date: String) -> Dictionary:
	for inv in inventories:
		if str(inv.get("date", "")) == date:
			return (inv.get("items", {}) as Dictionary).duplicate()
	return {}


## Tính bảng cân đối kho bánh cho một ngày
static func calculate_day_balance(
	date: String,
	orders: Array,
	wholesale_list: Array,
	productions: Array,
	inventories: Array,
	products: Array
) -> Dictionary:
	var retail_demand := sum_retail_demand(orders, date)
	var wholesale_demand := sum_wholesale_demand(wholesale_list, date)
	var opening_stock := get_opening_stock(inventories, date)

	var produced := {}
	for production in productions:
		if str(production.get("date", "")) == date:
			produced = (production.get("items", {}) as Dictionary).duplicate()
			break

	var rows: Array = []
	var total_demand := 0
	var total_produced := 0
	var total_opening := 0
	var total_surplus := 0
	var has_shortage := false
	var carry_over := {}

	for product in products:
		var product_id := str(product.get("id", ""))
		var r := int(retail_demand.get(product_id, 0))
		var w := int(wholesale_demand.get(product_id, 0))
		var total := r + w
		var stock := int(opening_stock.get(product_id, 0))
		var made := int(produced.get(product_id, 0))
		var supply := stock + made
		var surplus := supply - total

		rows.append({
			"productId": product_id,
			"name": str(product.get("name", "")),
			"icon": str(product.get("icon", "")),
			"retailDemand": r,
			"wholesaleDemand": w,
			"totalDemand": total,
			"openingStock": stock,
			"produced": made,
			"availableSupply": supply,
			"surplus": surplus,
		})

		total_demand += total
		total_produced += made
		total_opening += stock
		total_surplus += surplus
		if surplus < 0:
			has_shortage = true
		if surplus > 0:
			carry_over[product_id] = surplus

	return {
		"date": date,
		"rows": rows,
		"totalDemand": total_demand,
		"totalProduced": total_produced,
		"totalOpeningStock": total_opening,
		"totalSurplus": total_surplus,
		"hasShortage": has_shortage,
		"carryOver": carry_over,
	}


## Chuỗi ngày liên tiếp từ start_date tới end_date (bao gồm 2 đầu)
static func each_date(start_date: String, end_date: String) -> Array[String]:
	var result: Array[String] = []
	var start := Time.get_unix_time_from_datetime_string(start_date + "T00:00:00Z")
	var end := Time.get_unix_time_from_datetime_string(end_date + "T00:00:00Z")
	if start == 0 or end == 0:
		return [start_date]
	var cursor := start
	while cursor <= end:
		result.append(Time.get_date_string_from_unix_time(cursor))
		cursor += 86400
	return result


## Tính tồn kho gối đầu cho tất cả các ngày, tự động cộng dồn phần dư
static func build_inventory_chain(
	dates: Array,
	orders: Array,
	wholesale_list: Array,
	productions: Array,
	manual_inventories: Array,
	products: Array
) -> Dictionary:
	var chain := {}
	var carry := {}

	for date in dates:
		var manual := {}
		for inv in manual_inventories:
			if str(inv.get("date", "")) == str(date):
				manual = inv.get("items", {})
				break

		var opening := {}
		for product in products:
			var product_id := str(product.get("id", ""))
			var from_carry := int(carry.get(product_id, 0))
			var from_manual := int(manual.get(product_id, 0))
			var value := from_carry
			if from_manual > 0:
				value = maxi(from_carry, from_manual)
			if value > 0:
				opening[product_id] = value

		chain[str(date)] = opening

		var balance := calculate_day_balance(
			str(date), orders, wholesale_list, productions,
			[{"id": "tmp", "date": date, "items": opening}], products
		)
		carry = balance["carryOver"]

	return chain


## Tính tổng tiền sỉ cho 1 mối chợ theo danh mục sản phẩm
static func calculate_wholesale_total(items: Dictionary, products: Array) -> int:
	var product_map := {}
	for p in products:
		product_map[p.get("id", "")] = p
	var total := 0
	for product_id in items:
		var qty := int(items[product_id])
		if qty <= 0:
			continue
		var product = product_map.get(product_id, null)
		if product == null:
			continue
		total += BanhTet.get_wholesale_price(product) * qty
	return total
