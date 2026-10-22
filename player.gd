extends CharacterBody2D

var dano_ataque: int = 0
var alvos_atingidos: Array[Area2D] = []
var atacando: bool = false

const SPEED = 200
const VIDA_MAXIMA: int = 250
var vida_atual: int = VIDA_MAXIMA
var recebendo_dano: bool = false
var morto: bool = false

#É necessario x soco para usar o taco
const SOCOS_NECESSARIOS: int = 3
var contador_socos: int = 0
var ultima_direcao_esquerda: bool = false


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var hurtbox: Area2D = $HurtBox
@onready var colisao: CollisionShape2D = $CollisionShape2D

@onready var hitbox: Area2D = $HitBox
@onready var punch: CollisionShape2D = $HitBox/Punch
@onready var kick: CollisionPolygon2D = $HitBox/Kick
@onready var baseballBet: CollisionPolygon2D = $HitBox/BaseballBet

@onready var punch_x: float = punch.position.x
@onready var kick_x: float = kick.position.x
@onready var baseballBet_x: float = baseballBet.position.x

@onready var kick_poligono_original: PackedVector2Array = kick.polygon.duplicate()
@onready var taco_poligono_original: PackedVector2Array = baseballBet.polygon.duplicate()


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("Idle")
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	sprite.frame_changed.connect(_on_frame_changed)
	desativar_hitboxes()
	


func _on_animation_finished() -> void:
	if morto:
		get_tree().quit()
		return

	if recebendo_dano:
		recebendo_dano = false
		sprite.play("Idle")
		return

	if atacando:
		desativar_hitboxes()
		atacando = false
		sprite.play("Idle")


func _physics_process(_delta: float) -> void:
	
#Teste de dano
	#if Input.is_key_pressed(KEY_H) and not morto and not recebendo_dano:
	#	receber_dano(10)
	#if Input.is_key_pressed(KEY_J) and not morto and not recebendo_dano:
	#	receber_dano(25, true)
		
	if morto or recebendo_dano:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	attacking()
	
	if atacando:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	var direction := Input.get_vector("ui_left", "ui_right","ui_up","ui_down")
	
	velocity = direction * SPEED
	move_and_slide()
	verificar_fim_fase()
	atualizar_animacao(direction)
	
func attacking() -> void:
	if atacando:
		return

	if Input.is_action_just_pressed("Atk1-punch"):
		executar_ataque("Atk1")
	elif Input.is_action_just_pressed("Atk2-kick"):
		executar_ataque("Atk2")
	elif Input.is_action_just_pressed("Atk3-super"):
		if contador_socos >= SOCOS_NECESSARIOS:
			executar_ataque("Atk3")

func executar_ataque(animacao: String) -> void:
	match animacao:
		"Atk1":
			contador_socos = mini(contador_socos + 1, SOCOS_NECESSARIOS)
		"Atk3":
			contador_socos = 0
	
	alvos_atingidos.clear()
	atacando = true
	desativar_hitboxes()
	sprite.play(animacao)


func desativar_hitboxes() -> void:
	punch.set_deferred("disabled", true)
	kick.set_deferred("disabled", true)
	baseballBet.set_deferred("disabled", true)


func configurar_hitbox(animacao: String) -> void:
	desativar_hitboxes()

	match animacao:
		"Atk1":
			punch.set_deferred("disabled", false)
			dano_ataque = 15

		"Atk2":
			kick.set_deferred("disabled", false)
			dano_ataque = 25

		"Atk3":
			baseballBet.set_deferred("disabled", false)
			dano_ataque = 75


func atualizar_direcao(direcao_x: float) -> void:
	if direcao_x == 0:
		return
		
	var olhando_esquerda := direcao_x < 0
	if olhando_esquerda == ultima_direcao_esquerda:
		return
	ultima_direcao_esquerda = olhando_esquerda
	
	sprite.flip_h = olhando_esquerda
	var multiplicador: float = -1.0 if olhando_esquerda else 1.0

	punch.position.x = punch_x * multiplicador
	kick.position.x = kick_x * multiplicador
	baseballBet.position.x = baseballBet_x * multiplicador
	
	if olhando_esquerda:
		hurtbox.scale.x = -1
		kick.polygon = espelhar_poligono(kick_poligono_original)
		baseballBet.polygon = espelhar_poligono(taco_poligono_original)
	else:
		hurtbox.scale.x = 1
		kick.polygon = kick_poligono_original
		baseballBet.polygon = taco_poligono_original


func atualizar_animacao(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		if sprite.animation != "Idle":
			sprite.play("Idle")
	else:
		if sprite.animation != "Walk":
			sprite.play("Walk")
			
		atualizar_direcao(direction.x)
				


func espelhar_poligono(pontos: PackedVector2Array) -> PackedVector2Array:
	var resultado := PackedVector2Array()

	for ponto in pontos:
		resultado.append(Vector2(-ponto.x, ponto.y))

	resultado.reverse()
	return resultado


func receber_dano(dano: int, ataque_especial: bool = false) -> void:
	if morto or recebendo_dano:
		return

	vida_atual = maxi(vida_atual - dano, 0)
	print("Vida da protagonista: ", vida_atual)

	atacando = false
	desativar_hitboxes()
	velocity = Vector2.ZERO

	if vida_atual == 0:
		morto = true
		sprite.play("Hurt3(knockdown)")
	else:
		recebendo_dano = true

		if ataque_especial:
			sprite.play("Hurt2")
		else:
			sprite.play("Hurt1")

func _on_frame_changed() -> void:
	if not atacando:
		return

	desativar_hitboxes()

	match sprite.animation:
		"Atk1":
			if sprite.frame >= 3 and sprite.frame <= 4:
				configurar_hitbox("Atk1")

		"Atk2":
			if sprite.frame >= 2 and sprite.frame <= 4:
				configurar_hitbox("Atk2")

		"Atk3":
			if sprite.frame >= 5 and sprite.frame <= 8:
				configurar_hitbox("Atk3")

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("PLAYER HITBOX detectou: ", area.name)
	print("Grupo enemy_hurtbox: ", area.is_in_group("enemy_hurtbox"))
	if not atacando:
		return

	if area in alvos_atingidos:
		return

	if not area.is_in_group("enemy_hurtbox"):
		return

	var inimigo := area.get_parent()

	if inimigo.has_method("receber_dano"):
		alvos_atingidos.append(area)
		inimigo.receber_dano(dano_ataque)
		

func verificar_fim_fase() -> void:
	for i in get_slide_collision_count():
		var colisao_atual := get_slide_collision(i)

		var corpo := colisao_atual.get_collider() as CollisionObject2D
		if corpo == null:
			continue

		var indice := colisao_atual.get_collider_shape_index()
		var dono_id := corpo.shape_find_owner(indice)
		var forma := corpo.shape_owner_get_owner(dono_id)

		if forma != null and forma.name == "RighWall":
			print("Fim da fase! Vitória!")
			get_tree().quit()
			return
