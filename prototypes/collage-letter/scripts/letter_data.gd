extends RefCounted
static func fresh() -> Dictionary:
	return {"letter_id":Crypto.new().generate_random_bytes(16).hex_encode(),"sender":"","recipient":"","full_text":"","created_time":Time.get_datetime_string_from_system(true),"letter_type":"npc","reply_to":null,"completed":false,"sealed":false,"sent":false,"author_id":"","reply_chain_id":"","required_keywords":[],"forbidden_keywords":[],"tone":""}
static func restore(saved: Dictionary) -> Dictionary:
	var result:=fresh();result.merge(saved,true);return result
