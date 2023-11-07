class_name SpriteResource extends Resource
# describes a sprite: a folder with a sprite.tef file and other, arbitrary resources
# loading a sprite.tef file returns a SpriteResource


# the tag read from sprite.tef
var tag: Tag = null
# ImageTexture containing the atlas the TextureAtlases refer to
var atlas: ImageTexture
# map of file paths relative to the sprite folder to TextureAtlas instances
var textures: Dictionary = {}
