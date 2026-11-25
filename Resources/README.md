# Ícone do Cruzador

`AppIcon.png` é a arte fonte gerada pela ferramenta integrada `image_gen` para o pedido de um navio cruzador no mar. A transparência foi preservada. `scripts/build-icon.sh` usa sips e iconutil para produzir os tamanhos padrão e o ICNS em `build/`; o build inclui esse arquivo e declara `CFBundleIconFile`.

Prompt utilizado:

> Use case: stylized-concept. Asset type: finished macOS application icon for Cruzador, square 1024 x 1024. Primary request: a naval cruiser sailing at sea. Polished sculpted illustration, a recognizable elegant steel cruiser in three-quarter bow view, moving through deep ocean waves with a clear white wake. Strong simple silhouette, substantial ship occupying the center, readable at small Dock sizes, restrained detail. Ocean and sky contained in a softly rounded square macOS icon tile with generous safe margins, subtle depth, refined lighting. No lettering, numbers, logos, badges, watermark, flags or surrounding mockup. One single icon, straight-on full canvas, transparent outside the rounded tile.

A ferramenta retornou uma fonte de 1254 × 1254; os tamanhos 16–1024 px do ICNS são derivados durante o build. A prévia de 128 px foi inspecionada visualmente.
