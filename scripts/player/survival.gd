class_name Survival
extends RefCounted
## Потребности и состояние тела. Все показатели 0..100 (кроме температуры тела, °C).
## Скорости заданы в «единицах за игровой час» — поэтому выживание не зависит от FPS
## и от длины суток, а игрок всегда успевает среагировать на предупреждения.

const COMFORT := 16.0       ## «ощущаемая» температура, при которой тело в равновесии без одежды (+ утепление)
const NORMAL_TEMP := 36.6

var hunger := 85.0          ## сытость
var thirst := 80.0          ## вода
var sleep := 85.0           ## бодрость (сон)
var stamina := 100.0        ## выносливость (бег)
var body_temp := 36.6
var health := 100.0
var wet := 0.0              ## 0..1
var sick := 0.0             ## отравление 0..100
var bleeding := false
var hum_exposure := 0.0     ## 0..100, дезориентация от Гула
var earplugs_min := 0.0     ## минут защиты берушами
var feels_temp := 10.0      ## для интерфейса
var last_damage_cause := ""
var _damage_by_cause := {}


## real_delta — секунды; minutes — игровые минуты за этот кадр; ctx — окружение.
func tick(real_delta: float, minutes: float, ctx: Dictionary) -> void:
	var hrs := minutes / 60.0
	var mult := Settings.drain_mult()
	var sick_k := 1.4 if sick > 30.0 else 1.0
	var sprint_k := 1.6 if ctx.get("sprinting", false) else 1.0
	hunger = maxf(0.0, hunger - 1.25 * hrs * mult * sick_k * (1.2 if body_temp < 36.0 else 1.0))
	thirst = maxf(0.0, thirst - 2.0 * hrs * mult * sick_k * sprint_k)
	if not ctx.get("sleeping", false):
		sleep = maxf(0.0, sleep - 3.6 * hrs * mult)
	sick = maxf(0.0, sick - 6.0 * hrs)
	earplugs_min = maxf(0.0, earplugs_min - minutes)

	# --- выносливость (в реальном времени)
	var regen := 10.0
	if sleep < 20.0 or hunger < 15.0:
		regen *= 0.5
	if sick > 30.0:
		regen *= 0.6
	if ctx.get("sprinting", false):
		stamina = maxf(0.0, stamina - 13.0 * real_delta)
	elif ctx.get("moving", false):
		stamina = minf(100.0, stamina + regen * 0.5 * real_delta)
	else:
		stamina = minf(100.0, stamina + regen * real_delta)

	# --- мокрость
	if ctx.get("in_water", false):
		wet = minf(1.0, wet + 0.08 * minutes)
	elif ctx.get("raining", false) and not ctx.get("indoors", false):
		wet = minf(1.0, wet + 0.012 * minutes * ctx.get("rain_intensity", 1.0) * (1.0 - ctx.get("rain_protect", 0.0)))
	else:
		var dry := 0.004
		if ctx.get("indoors", false):
			dry = 0.008
		if ctx.get("near_fire", false):
			dry = 0.05
		wet = maxf(0.0, wet - dry * minutes)

	# --- температура
	var air: float = ctx.get("air_temp", 8.0)
	var feels := air
	if ctx.get("indoors", false):
		feels += 7.0
	elif ctx.get("wind", 0.0) > 0.0:
		feels -= ctx.get("wind", 0.0) * 4.0
	if ctx.get("near_fire", false):
		feels += 22.0
	feels -= wet * 8.0
	feels_temp = feels
	var insulation: float = ctx.get("insulation", 0.5)
	var balance := feels + insulation * 16.0 - COMFORT
	if ctx.get("moving", false):
		balance += 2.0
	if ctx.get("sprinting", false):
		balance += 4.0
	if balance < 0.0:
		body_temp += balance * 0.0016 * minutes
	else:
		body_temp += minf(balance, 10.0) * 0.004 * minutes
	body_temp = clampf(body_temp, 33.0, NORMAL_TEMP if balance < 14.0 else 37.4)
	if balance > 0.0 and body_temp > NORMAL_TEMP and balance < 14.0:
		body_temp = move_toward(body_temp, NORMAL_TEMP, 0.01 * minutes)

	# --- Гул
	var protect: float = ctx.get("hum_protect", 0.0)
	if earplugs_min > 0.0:
		protect = maxf(protect, 0.85)
	if ctx.get("hum_active", false):
		hum_exposure = minf(100.0, hum_exposure + (1.0 - protect) * 2.2 * minutes)
		if hum_exposure > 30.0:
			sleep = maxf(0.0, sleep - 0.1 * minutes)
	else:
		hum_exposure = maxf(0.0, hum_exposure - 3.0 * minutes)

	# --- урон и восстановление (в единицах/игровой час)
	_damage_by_cause.clear()
	if hunger <= 0.0:
		_hurt(6.0 * hrs, "голод")
	if thirst <= 0.0:
		_hurt(10.0 * hrs, "обезвоживание")
	if body_temp < 35.0:
		_hurt((35.0 - body_temp + 0.4) * 9.0 * hrs, "переохлаждение")
	if sleep <= 0.0:
		_hurt(3.0 * hrs, "истощение")
	if bleeding:
		_hurt(14.0 * hrs, "кровопотеря")
	if sick > 60.0:
		_hurt(4.0 * hrs, "отравление")
	if hum_exposure > 85.0:
		_hurt(12.0 * hrs, "Гул")
	if hunger > 35.0 and thirst > 35.0 and body_temp > 35.8 and sleep > 15.0 and not bleeding and sick < 40.0:
		health = minf(100.0, health + 1.6 * hrs * (1.0 + GameState.skill_level("medicine") * 0.15))


func _hurt(amount: float, cause: String) -> void:
	if amount <= 0.0:
		return
	health -= amount
	_damage_by_cause[cause] = float(_damage_by_cause.get(cause, 0.0)) + amount
	last_damage_cause = cause


func damage(amount: float, cause: String) -> void:
	health -= amount
	last_damage_cause = cause


func is_dead() -> bool:
	return health <= 0.0


## Применить эффекты предмета (из items.json → use).
func apply_use(use: Dictionary) -> void:
	hunger = clampf(hunger + float(use.get("hunger", 0)), 0.0, 100.0)
	thirst = clampf(thirst + float(use.get("thirst", 0)), 0.0, 100.0)
	sleep = clampf(sleep + float(use.get("sleep", 0)), 0.0, 100.0)
	var med_bonus := 1.0 + GameState.skill_level("medicine") * 0.12
	var hp := float(use.get("health", 0))
	health = clampf(health + (hp * med_bonus if hp > 0 else hp), 0.0, 100.0)
	body_temp = minf(37.2, body_temp + float(use.get("warmth", 0)) * 0.08)
	sick = clampf(sick + float(use.get("sick", 0)), 0.0, 100.0)
	if use.get("bleed", false):
		bleeding = false
	if use.has("earplugs"):
		earplugs_min = 360.0


## Предупреждения для HUD: [[текст, уровень 1..3], ...]
func warnings() -> Array:
	var w: Array = []
	if hunger < 25.0:
		w.append(["Голод", 3 if hunger < 8.0 else 2])
	if thirst < 25.0:
		w.append(["Жажда", 3 if thirst < 8.0 else 2])
	if sleep < 20.0:
		w.append(["Усталость", 3 if sleep < 5.0 else 2])
	if body_temp < 35.8:
		w.append(["Холодно", 3 if body_temp < 35.0 else 2])
	if wet > 0.5:
		w.append(["Промок", 1])
	if bleeding:
		w.append(["Кровотечение", 3])
	if sick > 30.0:
		w.append(["Отравление", 2 if sick < 60.0 else 3])
	if hum_exposure > 20.0:
		w.append(["Дезориентация", 3 if hum_exposure > 60.0 else 2])
	return w


func to_dict() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "sleep": sleep, "stamina": stamina, "body_temp": body_temp,
		"health": health, "wet": wet, "sick": sick, "bleeding": bleeding, "hum": hum_exposure, "earplugs": earplugs_min}


func from_dict(d: Dictionary) -> void:
	hunger = float(d.get("hunger", 80))
	thirst = float(d.get("thirst", 80))
	sleep = float(d.get("sleep", 80))
	stamina = float(d.get("stamina", 100))
	body_temp = float(d.get("body_temp", 36.6))
	health = float(d.get("health", 100))
	wet = float(d.get("wet", 0))
	sick = float(d.get("sick", 0))
	bleeding = bool(d.get("bleeding", false))
	hum_exposure = float(d.get("hum", 0))
	earplugs_min = float(d.get("earplugs", 0))
