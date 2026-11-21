extends Node
## Глобальная шина событий. Системы общаются через сигналы и не зависят друг от друга напрямую.

# --- Игрок и предметы
signal item_picked(item_id: String, count: int)
signal item_used(item_id: String)
signal item_crafted(item_id: String, count: int)
signal inventory_changed
signal equipment_changed
signal player_damaged(amount: float, cause: String)
signal player_died(cause: String)
signal player_slept(hours: float)

# --- Интерфейс
signal notify(text: String, kind: String)          ## kind: info | good | warn | bad | lore
signal prompt_changed(text: String)
signal open_screen(screen: String, payload: Variant) ## inventory, container, crafting, journal, map, radio, dialogue, note, build
signal close_screens
signal hud_flash(color: Color)

# --- Мир
signal noise_emitted(position: Vector3, radius: float, source: Node)
signal location_discovered(location_id: String)
signal time_hour(day: int, hour: int)
signal weather_changed(kind: String)
signal hum_warning(seconds_left: float)
signal hum_started
signal hum_ended
signal world_flag_changed(key: String)

# --- Сюжет
signal journal_added(entry_id: String)
signal note_read(note_id: String)
signal quest_updated(quest_id: String)
signal npc_talked(npc_id: String)
signal skill_level_up(skill: String, level: int)

# --- Система
signal settings_changed
signal game_loaded
signal request_save(slot: String)
