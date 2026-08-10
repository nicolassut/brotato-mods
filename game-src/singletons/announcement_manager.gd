extends Node

signal announcement_ready()

var display_announcement: = false
var initial_display: = true

var _http_request: HTTPRequest
var _status_to_fetch: = "published"
var _announcement_url: = "https://announcements.blobfishgames.com/items/announcement"
var _query_params: = "?fields[]=*.*&filter={\"status\":{\"_eq\":\"{0}\"},\"platforms\":{\"platform_name\":{\"_eq\":\"{1}\"}}}"
var _asset_url: = "https://announcements.blobfishgames.com/assets/"

var _announcement_id: String
var _image_lookup: Dictionary
var _image_to_download: String


func _ready() -> void :
	if OS.get_name().begins_with("Seaven"):
		return

	_http_request = HTTPRequest.new()
	_http_request.timeout = 20
	add_child(_http_request)
	var _http_err = _http_request.connect("request_completed", self, "_on_announcements_fetched")
	var _lang_err = ProgressData.connect("language_changed", self, "_on_language_changed")

	_query_params = _query_params.replace("{0}", _status_to_fetch)
	_query_params = _query_params.replace("{1}", Platform.get_type_as_string().to_lower())
	var error = _http_request.request(_announcement_url + _query_params)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _on_announcements_fetched(result, _response_code, _headers, body) -> void :
	_http_request.disconnect("request_completed", self, "_on_announcements_fetched")
	if result != HTTPRequest.RESULT_SUCCESS or _response_code != 200:
		return

	var parsed = parse_json(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.has("data"):
		return

	var data = parsed.data
	for announcement in data:
		if not announcement["id"] in ProgressData.read_announcements:
			var current_utc_unix: = Time.get_unix_time_from_system()
			var date_start_unix: = Time.get_unix_time_from_datetime_string(announcement["date_start"])
			var date_end_unix: = Time.get_unix_time_from_datetime_string(announcement["date_end"])
			if date_start_unix <= current_utc_unix and current_utc_unix <= date_end_unix:
				for platform in announcement["platforms"]:
					if platform["platform_name"].to_lower() == Platform.get_type_as_string().to_lower():
						_announcement_id = announcement["id"]
						add_translations(announcement)
						break
				break


func add_translations(announcement: Dictionary) -> void :
	for translation in announcement.translations:
		var translation_res = Translation.new()
		translation_res.locale = translation["language_code"]
		if translation.get("header"):
			translation_res.add_message("ANNOUNCEMENT_HEADER", translation["header"])
		if translation.get("content"):
			translation_res.add_message("ANNOUNCEMENT_CONTENT", translation["content"])
		if translation.get("link"):
			translation_res.add_message("ANNOUNCEMENT_LINK", translation["link"])
		if translation.get("image"):
			translation_res.add_message("ANNOUNCEMENT_IMAGE_ID", translation["image"])
		TranslationServer.add_translation(translation_res)

	get_tree().notification(NOTIFICATION_TRANSLATION_CHANGED)
	_download_image()


func _download_image() -> void :
	_image_to_download = tr("ANNOUNCEMENT_IMAGE_ID")
	if _image_to_download in _image_lookup:
		display_announcement = true
		_image_to_download = ""
		emit_signal("announcement_ready")
		return

	var _err = _http_request.connect("request_completed", self, "_on_image_downloaded")
	_image_to_download = tr("ANNOUNCEMENT_IMAGE_ID")
	var error = _http_request.request(_asset_url + _image_to_download)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _on_image_downloaded(result, _response_code, _headers, body) -> void :
	_http_request.disconnect("request_completed", self, "_on_image_downloaded")
	if result != HTTPRequest.RESULT_SUCCESS:
		return

	var downloaded_image = Image.new()
	var error = downloaded_image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
		return

	var texture = ImageTexture.new()
	texture.create_from_image(downloaded_image)
	_image_lookup[_image_to_download] = texture
	_image_to_download = ""

	display_announcement = true
	emit_signal("announcement_ready")


func _on_language_changed() -> void :
	if display_announcement:
		initial_display = true
		display_announcement = false
		_download_image()


func announcement_read() -> void :
	ProgressData.read_announcements.append(_announcement_id)
	ProgressData.save()
	display_announcement = false


func get_image() -> ImageTexture:
	return _image_lookup.get(tr("ANNOUNCEMENT_IMAGE_ID"))
