# Leaves Game

Um jogo Roblox onde folhas são spawnadas periodicamente, os jogadores podem coletá-las manualmente ou com um “aspirador” ao atravessar uma parede especial, e navegar entre múltiplos mundos via UI e teleporte. Projeto organizado para uso com Rojo.

## Sumário
- Gameplay e sistemas
- Estrutura do projeto
- Como rodar com Rojo
- Teleporte multi-mundos (Studio e Produção)
- UI e interação
- Configurações personalizáveis
- Persistência (leaderboard)

## Gameplay e Sistemas

- Spawn de folhas: folhas caem sobre a plataforma `LeavesSpawn` até um limite, com física simples e estabilização ao pousar.
- Aspirador: ao atravessar a `TransformWall`, o jogador ganha poderes de sucção; folhas próximas são atraídas com VFX (trail neon, luz, partículas) e coletadas.
- Leaderboard: pontuação “LeavesCollected” exibe no leaderstats e persiste via DataStore.
- Teleporte: seleção de mundo via GUI abre um painel; ao escolher um mundo, o servidor teleporta (produção) ou simula (Studio) e posiciona no spawn correto.

## Estrutura do Projeto

```
src/
├── client/
│   ├── init.client.luau
│   └── UI/
│       ├── UiController.client.luau       # Abre/fecha painéis; espelha contador de folhas
│       └── WorldButton.client.luau        # Binder que conecta botões do painel "GUI Worlds"
├── server/
│   ├── init.server.luau
│   ├── Modules/
│   │   └── Leaf.module.luau               # Módulo de criação/comportamento das folhas
│   └── Systems/
│       ├── LeaderboardSystem.server.luau  # Leaderstats + DataStore (persistência)
│       ├── LeafManager.server.luau        # Loop de spawn de folhas
│       ├── VacuumSystem.server.luau       # Mecânica de sucção e coleta + VFX
│       ├── TeleportManager.server.luau    # Recebe clique de mundo e teleporta/simula
│       └── SpawnRouter.server.luau        # No destino, posiciona no spawn correto
└── shared/
    └── Hello.luau
```

Objetos seed no Workspace (definidos em `default.project.json`):
- `LeavesSpawn` (Part ancorada)
- `TransformWall` (Part translúcida)
- Modelo `Leaves` com uma peça base `Leaf`

## Como rodar com Rojo

1) Gerar o place (opcional se já possui `Leaves Game.rbxlx`):

```powershell
rojo build -o "Leaves Game.rbxlx"
```

2) Abrir o place no Roblox Studio e iniciar o servidor do Rojo:

```powershell
rojo serve
```

Opcional: Se usar [Aftman](https://github.com/LPGhatguy/aftman), rode `aftman install` para instalar ferramentas (Rojo, etc.).

## Teleporte Multi‑Mundos

Fluxo:
- O botão “Worlds” (menu esquerdo) apenas abre o painel “GUI Worlds”.
- Dentro do painel “GUI Worlds”, cada botão de mundo tem atributo `WorldId` (Number) ou um nome/texto com dígito (ex.: “World2”).
- `WorldButton.client.luau` detecta esses botões e envia o `worldId` via `GuiButtonClickEvent` (RemoteEvent em `ReplicatedStorage`).
- `TeleportManager.server.luau` resolve o destino pelo mapa `WORLD_PLACES` e:
  - Em Studio: simula teleporte movendo o personagem para `StudioTeleportSpawn{worldId}` (se existir), com offset vertical para não “enterrar”.
  - Em produção: usa TeleportService com `TeleportOptions`, envia `TeleportData` com `spawnName = "WorldSpawn{worldId}"` e `worldId`.
- No destino, `SpawnRouter.server.luau` lê o `TeleportData` e move o jogador para `WorldSpawn{worldId}`, também com offset vertical.

Requisitos:
- Criar um `RemoteEvent` chamado `GuiButtonClickEvent` em `ReplicatedStorage` (se não existir no place).
- Studio (teste): adicionar Parts `StudioTeleportSpawn1..4` (ou `StudioTeleportSpawn` padrão), ancoradas e visíveis.
- Produção (cada place de mundo): adicionar Parts `WorldSpawn1..4` para posicionamento.
- Produção: atualizar `WORLD_PLACES` com os `PlaceId` reais de cada mundo.

## UI e Interação

- Menu esquerdo:
  - Botão “Worlds” abre o painel “GUI Worlds” ao centro, com tween.
  - Outros botões fecham o painel atual.
  - Botão “Exit” fecha o painel atual.
- Painel “GUI Worlds”:
  - Botões de mundo internos disparam teleporte somente quando um `worldId` numérico é detectado.
- Contador “Leaves Counter” (lado direito):
  - `UiController.client.luau` espelha o valor de `leaderstats.LeavesCollected`.
  - Formatação compacta: 1.2k, 3.4M, 10B, 500T.

## Configurações Personalizáveis

LeafManager (`src/server/Systems/LeafManager.server.luau`)
- `SPAWN_INTERVAL`: tempo entre spawns
- `MAX_LEAVES`: máximo de folhas simultâneas

VacuumSystem (`src/server/Systems/VacuumSystem.server.luau`)
- Alcance, ângulo frontal e thresholds de coleta
- VFX: largura do Trail via `WidthScale`, partículas e luz

TeleportManager (`src/server/Systems/TeleportManager.server.luau`)
- `WORLD_PLACES`: mapeamento `worldId -> PlaceId`
- `SIMULATE_IN_STUDIO`: alterna a simulação local em Studio

UiController (`src/client/UI/UiController.client.luau`)
- Nomes/estruturas de ScreenGuis alvo (ex.: “GUI Worlds”, “GUI Buttons Left/Right”)
- Tween tempo/estilo/direção

## Persistência (Leaderboard)

`LeaderboardSystem.server.luau` cria `leaderstats.LeavesCollected`, carrega e salva via DataStore:
- Em Studio, ative “Enable Studio Access to API Services” para testes de DataStore.
- Há auto‑save periódico e salvamento ao sair.

## Dicas e Troubleshooting

- Personagem aparecendo dentro/abaixo do spawn:
  - Certifique-se de que os spawns (`StudioTeleportSpawnN`/`WorldSpawnN`) estão ancorados, acima do chão, e sem colisões sobrepostas. O código já aplica offset vertical.
- Botões de mundo não teleportam:
  - Garanta que os botões estejam dentro do painel “GUI Worlds”, tenham `WorldId` numérico ou um número no nome/texto, e que o `GuiButtonClickEvent` exista em `ReplicatedStorage`.
- Folhas não spawnam:
  - Verifique se o módulo `Leaf` é encontrado por `LeafManager` (há espera por `WaitForChild`). Veja o Output para logs.

—

Para mais detalhes sobre Rojo, consulte a documentação oficial: https://rojo.space/docs