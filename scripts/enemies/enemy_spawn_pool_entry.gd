class_name EnemySpawnPoolEntry
extends Resource

## A single weighted slot inside an EnemySpawnPool.

@export var enemy: EnemyDefinition
@export_range(0.0, 1000.0, 0.1) var weight := 1.0
