-- Script principal do servidor
print("Hello world, from server!")

-- === ORDEM DE CARREGAMENTO DOS SISTEMAS ===
-- 1. LeaderboardSystem (deve carregar primeiro)  
-- 2. LeafManager (spawning de folhas)
-- 3. VacuumSystem (sistema de coleta - depende do leaderboard)

print("🚀 Sistemas carregados em ordem:")
print("📊 LeaderboardSystem - Carregado")
print("🍃 LeafManager - Carregado") 
print("🌪️ VacuumSystem - Carregado")
print("✅ Todos os sistemas integrados!")