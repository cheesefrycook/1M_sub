extends Node2D
class_name Battler
## Spawns enemies and controls the flow of battle.
## 
## This class holds a list of all the enemies, so it's a good central place to dispatch
## battle actions (player clicking on enemies, enemy attacks, applying status).


@export var enemies_to_summon: Array[PackedScene]
@export var enemy_spacing: float = 50.0

var _enemy_list: Array[Entity]


func _ready() -> void:
	_summon_enemies()
	
	# check if our player has been initialized already. If not, wait for the signal
	if (PlayerManager.player == null):
		PlayerManager.on_player_initialized.connect(_on_player_initialized)
	else:
		_on_player_initialized()
		
	PhaseManager.on_phase_changed.connect(_on_phase_changed)


func _summon_enemies() -> void:
	for enemy_index: int in enemies_to_summon.size():
		var enemy_instance: Node = enemies_to_summon[enemy_index].instantiate()
		add_child(enemy_instance)
		_enemy_list.append(enemy_instance)
		enemy_instance.get_click_handler().on_click.connect(_on_enemy_clicked.bind(enemy_instance))
		enemy_instance.position.x += enemy_spacing * enemy_index
	
	# setup party
	for enemy: Entity in _enemy_list:
		enemy.get_party_component().set_party(_enemy_list)


func _on_player_initialized() -> void:
	PlayerManager.player.get_click_handler().on_click.connect(_on_player_clicked)
	PlayerManager.player.get_party_component().add_party_member(PlayerManager.player)


func _on_phase_changed(new_phase: Enums.Phase, _old_phase: Enums.Phase) -> void:
	if new_phase == Enums.Phase.PLAYER_ATTACKING:
		_on_player_start_turn()
	
	if new_phase == Enums.Phase.ENEMY_ATTACKING:
		_on_enemy_start_turn()


# player start phase: apply status
func _on_player_start_turn() -> void:
	PlayerManager.player.get_status_component().apply_turn_start_status()


# enemy start phase: apply status and attack player. Afterwards, set phase to player phase
# NOTE: these are applied in two separate loops just encase an enemy affects another member of their
# party with a status during their attack
func _on_enemy_start_turn() -> void:
	# apply status
	for enemy: Entity in _enemy_list:
		enemy.get_status_component().apply_turn_start_status()
	
	# enemy attack
	for enemy: Entity in _enemy_list:
		var success: bool = _on_attack(enemy.get_behavior_component().attack, enemy, PlayerManager.player)
		assert(success == true, "Enemy failed to attack.")
	
	PhaseManager.set_phase(Enums.Phase.PLAYER_ATTACKING)


# when player clicks themselves (eg: healing card)
func _on_player_clicked() -> void:
	_try_player_play_card_on_entity(PlayerManager.player)


# when player clicks an enemy (eg: damage card)
func _on_enemy_clicked(enemy: Enemy) -> void:
	_try_player_play_card_on_entity(enemy)


func _try_player_play_card_on_entity(entity: Entity) -> void:
	if CardManager.is_card_queued():
		var success: bool = _on_attack(CardManager.queued_card.card_data, PlayerManager.player, entity)
		if success:
			CardManager.notify_successful_play()


func _on_attack(attack_card: CardBase, caster: Entity, target: Entity) -> bool:
	return attack_card.try_play_card(caster, target)
