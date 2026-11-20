# Nekix ChopShop

Trabalho de desmanche para FiveM: roube um veículo, leve até o ferro-velho, desmonte e venda as peças. Funciona com ESX, QBCore e Qbox. Toda decisão (trabalho, veículo, peças, loot, pagamento, XP) é tomada pelo servidor.

**Documentação em outros idiomas:** [English](../../README.md) | [Español](README.es.md) | Português (Brasil) | [Français](README.fr.md) | [Deutsch](README.de.md)

## Recursos

- **Frameworks:** ESX, QBCore e Qbox, detectados automaticamente (`Config.Framework = 'auto'`).
- **Inventários:** ox_inventory, qs-inventory, core_inventory, ps-inventory e qb-inventory, detectados automaticamente, mais um adaptador `custom` para qualquer outro inventário.
- **Trabalhos com autoridade do servidor:** o servidor escolhe o veículo, faz o spawn, valida distâncias, tempos e lockpick, e decide todas as recompensas. Um cliente modificado não consegue dar itens, dinheiro nem XP a si mesmo.
- **Categorias de veículo e loot:** veículos de categoria baixa, média e alta, cada uma com seu pagamento, qualidade de item e tabela de loot.
- **Reputação:** XP e níveis por personagem (oxmysql) que liberam categorias de veículo e bônus.
- **Mais peças:** portas, capô, porta-malas, motor, bancos dianteiros e rodas, com uma ordem de "remova isto primeiro" imposta pelo servidor.
- **Polícia:** mínimo de policiais em serviço e alerta de despacho com 9 scripts compatíveis mais `custom`.
- **Chaves de veículo:** o dono do trabalho recebe as chaves do veículo após o lockpick, com 7 scripts compatíveis mais `custom`.
- **Sistema de parceiro:** o dono pode convidar um parceiro antes de desmontar; o parceiro divide o trabalho e uma parte do XP.
- **Limites de tempo:** cronômetros de retirada e de desmanche; um trabalho expirado é cancelado e sua vaga no ferro-velho é liberada.
- **Cooldown persistente:** guardado no KVP do recurso (sem SQL), por personagem e por licença, com um comando de reinício para administradores.
- **NUI de ordem de serviço:** quadro de trabalhos, ficha do trabalho com anotações, notas soltas, convite de parceiro e comprador de peças. Pode ser desativada.
- **10 idiomas** pelos locales do ox_lib: en, es, fr, de, it, pt-br, pl, nl, tr, cs.
- **Logs no Discord** e verificador de versão.

## Requisitos

| Recurso | Observações |
| :--- | :--- |
| [ox_lib](https://github.com/overextended/ox_lib) | obrigatório |
| [ox_target](https://github.com/overextended/ox_target) | obrigatório |
| [oxmysql](https://github.com/overextended/oxmysql) | obrigatório (dependência do manifest). Com `Config.Reputation.Enabled = false` nenhum SQL é executado |
| OneSync | obrigatório (o servidor faz o spawn dos veículos) |
| `qbx_core`, `es_extended` ou `qb-core` | um deles |
| Um inventário | `ox_inventory`, `qs-inventory`, `core_inventory`, `ps-inventory`, `qb-inventory` ou um adaptador custom |

Opcional: um script de chaves de veículo e um script de despacho policial (veja "Chaves de veículo" e "Polícia e despacho").

## Instalação

1. **Baixe** o recurso e coloque a pasta no seu diretório de recursos. Mantenha o nome da pasta `nek_chopshop`: os exports o usam (`exports.nek_chopshop`).
2. **Adicione os itens** ao seu inventário. Abra o guia do seu inventário, copie o bloco e reinicie o inventário:

   | Inventário | Guia |
   | :--- | :--- |
   | ox_inventory | [docs/items/ox_inventory.md](../items/ox_inventory.md) |
   | qb-inventory | [docs/items/qb-inventory.md](../items/qb-inventory.md) |
   | ps-inventory | [docs/items/ps-inventory.md](../items/ps-inventory.md) |
   | qs-inventory | [docs/items/qs-inventory.md](../items/qs-inventory.md) |
   | core_inventory | [docs/items/core_inventory.md](../items/core_inventory.md) |
   | qualquer outro | [docs/items/custom.md](../items/custom.md) |

3. **Copie as imagens dos itens** da pasta `[assets]` para o diretório de imagens do seu inventário (`ox_inventory/web/images/`, `qb-inventory/html/images/`, ...; cada guia indica a pasta). Cada imagem tem o nome do seu item.
4. **Adicione o recurso ao `server.cfg`**, depois das dependências:

   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure oxmysql
   ensure qbx_core            # ou es_extended / qb-core
   ensure ox_inventory        # ou o seu inventário
   ensure qbx_vehiclekeys     # opcional: seu script de chaves
   ensure ps-dispatch         # opcional: seu script de despacho
   ensure nek_chopshop
   ```

5. **Banco de dados:** não há nada para importar. A tabela `nek_chopshop_reputation` é criada na primeira inicialização.
6. **Configuração:** deixe `Config.Framework = 'auto'` e `Config.Inventory = 'auto'`, a menos que precise forçar um. Revise [`shared/config.lua`](../../shared/config.lua).
7. **Idioma (opcional):** adicione `setr ox:locale "pt-br"` ao `server.cfg` (veja "Idiomas").
8. **Inicie o servidor** e confira o console: ele mostra o framework e o inventário encontrados e avisa sobre qualquer item não registrado.

## Como funciona um trabalho

1. O jogador pede um trabalho ao ped (opção de target ou quadro de trabalhos). O servidor verifica cooldown, policiais em serviço, categoria pela reputação e uma vaga livre no ferro-velho; depois faz o spawn do veículo e o marca no mapa.
2. O jogador arromba o veículo com lockpick (precisa de um item de `Config.LockpickItems` e de passar no minigame). O servidor entrega as chaves e envia o alerta à polícia.
3. O jogador dirige até o ferro-velho.
4. No ferro-velho o jogador pode convidar um parceiro e, em seguida, começa a desmontar.
5. Cada peça removida vai para o inventário. Quando todas as peças saem, o dono recebe `Config.FinishReward` e, se ativado, dinheiro. O veículo é destruído.
6. O jogador vende as peças no ped de venda.

## Visão geral da configuração

Todas as opções ficam em [`shared/config.lua`](../../shared/config.lua), cada uma com seu comentário. Agrupadas por área:

### Geral

| Opção | Descrição |
| :--- | :--- |
| `Config.Framework` | `'auto'` (padrão), `'esx'`, `'qbcore'` ou `'qbox'`. Ordem no auto: `qbx_core` > `es_extended` > `qb-core`. Um framework forçado que não está iniciado volta para a detecção automática. |
| `Config.Inventory` | `'auto'` (padrão), `'ox_inventory'`, `'qs-inventory'`, `'core_inventory'`, `'ps-inventory'`, `'qb-inventory'` ou `'custom'`. Veja "Inventário". |
| `Config.LockpickItems` | Itens que permitem arrombar o veículo do trabalho (basta um). Padrão `lockpick`, `advancedlockpick`, `advanced_lockpick`. |
| `Config.UseNUI` | `true` usa a NUI; `false` recorre aos menus e notificações do ox_lib. |
| `Config.Debug` | Mensagens de depuração. |
| `Config.AdminAce` | ACE autorizado a usar o comando de administração. Veja "Administração". |

### Trabalhos, recompensas e tempo

| Opção | Descrição |
| :--- | :--- |
| `Config.Cooldown` | Segundos entre trabalhos (padrão 3600). Os bônus de reputação podem encurtá-lo. |
| `Config.TimeLimit` | `Pickup` e `Scrap`, em minutos (padrão 20 e 10). Pickup vai de aceitar o trabalho até o início do desmanche; Scrap, do início até todas as peças serem removidas. Um trabalho que ultrapassa qualquer um dos dois é cancelado. |
| `Config.Payment` | `Enable`, `Min`, `Max`: dinheiro opcional por trabalho (desativado por padrão). Multiplicado pelo `payout` da categoria. |
| `Config.FinishReward` | Item entregue ao dono quando todas as peças são removidas (padrão `veh_suspension`), ou `false`. |
| `Config.ChopParts` | Peças que podem ser removidas. É a lista de permissão de recompensas: o servidor só recompensa as peças listadas aqui. Veja "Peças". |
| `Config.Coords` | `Spawns` (pontos de spawn de veículos) e `Scrap` (vagas do ferro-velho). |
| `Config.Tiers` | Categorias de veículo. Veja "Categorias de veículo e loot". |
| `Config.Reputation` | XP, níveis, bônus, decaimento. Veja "Reputação". |

### Peds e venda

| Opção | Descrição |
| :--- | :--- |
| `Config.Ped` | Ped do trabalho: `Model`, `Coords`, `Scenario`, `Target` (opções do ox_target), `Blip`. |
| `Config.SellPed` | Ped de venda: `Enable`, `Model`, `Coords`, `Scenario`, `Items` (item, preço base, rótulo), `QualityMultiplier`, `Blip`. |

Os rótulos (`label`, `Label` do blip, `label` do target) aceitam uma chave de locale; um texto literal também funciona.

### Polícia e chaves de veículo

| Opção | Descrição |
| :--- | :--- |
| `Config.Police` | `MinOnDuty`, `JobType`, `Jobs`, `Dispatch`. Veja "Polícia e despacho". |
| `Config.VehicleKeys` | `System`, `RemoveOnEnd`. Veja "Chaves de veículo". |

### Segurança (anti-exploit)

`Config.Security` guarda os limites do servidor (distâncias em metros, tempos em milissegundos):

| Opção | Padrão | Descrição |
| :--- | :--- | :--- |
| `PedDistance` | 10.0 | Distância máxima até o ped do trabalho para pedir um trabalho. |
| `SellDistance` | 10.0 | Distância máxima até o ped de venda para vender. |
| `ScrapDistance` | 15.0 | Distância máxima do veículo até o ponto de desmanche para começar a desmontar. |
| `PartDistance` | 6.0 | Distância máxima do jogador até o veículo para remover uma peça. |
| `PartnerDistance` | 20.0 | Distância máxima entre dono e parceiro ao atribuí-lo. |
| `PartInterval` | 2000 | Tempo mínimo entre duas remoções de peça do mesmo jogador. |
| `SpawnClearRadius` | 3.0 | Um ponto de spawn é ignorado se houver um veículo dentro deste raio. |
| `MaxAverageSpeed` | 60.0 | m/s. Uma entrega do spawn ao ferro-velho mais rápida que isso é tratada como teletransporte e rejeitada. |
| `WarnThrottle` | 30 | Segundos entre logs de requisições suspeitas do mesmo jogador. |
| `DispatchDistance` | 10.0 | Distância máxima até o veículo do trabalho quando chega o relatório do lockpick. |

### Logs

| Opção | Descrição |
| :--- | :--- |
| `Config.Discord` | `Username`, `AvatarUrl`, `Color` dos embeds. A URL do webhook **não** fica aqui: defina `Editable.Webhook` em `editable/server.lua`. |
| `Config.Logs` | `EnableItem`, `EnablePay`, `EnableFinish`, `EnableWarn`, `EnableReputation`, `Compact`. |

Os logs do Discord usam o idioma do servidor.

## Inventário

`Config.Inventory = 'auto'` usa o primeiro inventário iniciado desta lista:

| # | Recurso | Frameworks | Observações |
| :--- | :--- | :--- | :--- |
| 1 | `ox_inventory` | ESX, QBCore, Qbox | Suporte completo. |
| 2 | `qs-inventory` | ESX, QBCore, Qbox | Escrito a partir da documentação do fornecedor. |
| 3 | `core_inventory` | ESX, QBCore, Qbox | Escrito a partir da documentação do fornecedor; a venda por qualidade é degradada. |
| 4 | `ps-inventory` | QBCore | A verificação de espaço é uma estimativa; a venda por qualidade é degradada. |
| 5 | `qb-inventory` | QBCore | A venda por qualidade é degradada. |

- **Início tardio:** se nenhum inventário estiver rodando quando o recurso iniciar, ele espera e escolhe um assim que um recurso da lista iniciar. Mesmo assim, inicie seu inventário antes do nek_chopshop.
- **Forçar um:** informe o nome do recurso. Se ele não estiver iniciado, um aviso é impresso no console e a detecção automática é usada.
- **Qualquer outro inventário:** `Config.Inventory = 'custom'` e preencha `Editable.Inventory` em `editable/server.lua`. Veja [docs/items/custom.md](../items/custom.md).
- **Metadados de qualidade:** o ox_inventory guarda a qualidade da categoria em `metadata.quality`; os demais inventários usam `chopQuality`.
- As limitações conhecidas de cada inventário estão no fim do seu guia de itens.

## Polícia e despacho

### Mínimo de policiais em serviço

`Config.Police.MinOnDuty` é o número de policiais que precisam estar em serviço para liberar um trabalho (`0` desativa). A requisição é recusada no servidor e o quadro mostra "Not enough police on duty" (texto conforme o idioma).

- **Qbox / QBCore:** conta jogadores em serviço cujo tipo de trabalho é `Config.Police.JobType` (padrão `'leo'`). Com `JobType = false`, contam-se os nomes de trabalho em `Config.Police.Jobs`.
- **ESX:** conta jogadores com um trabalho de `Config.Police.Jobs` cujo `job.onDuty` não é `false` (um ESX antigo sem serviço conta todos do trabalho).
- Uma categoria pode adicionar `minPolice`; o requisito efetivo é o maior dos dois.

### Alerta

Um alerta por trabalho, enviado pelo servidor (a partir da sua varredura de trabalhos, ou quando o veículo é entregue) para que um cliente modificado não consiga pulá-lo. O cliente do ladrão pode disparar antes, logo após o lockpick; o servidor verifica se quem chama é o dono do trabalho, está na fase de retirada, está perto do veículo (`Config.Security.DispatchDistance`) e ainda não alertou. Local, placa e modelo sempre vêm do servidor.

`Config.Police.Dispatch.System`:

| Valor | Comportamento |
| :--- | :--- |
| `'auto'` | Primeiro script iniciado da lista abaixo. |
| um nome de script | Força esse script. |
| `'custom'` | Chama o seu próprio código (veja abaixo). |
| `false` | Sem alerta. |

Scripts compatíveis, em ordem de detecção automática:

| # | Recurso | Roda em |
| :--- | :--- | :--- |
| 1 | `ps-dispatch` | cliente |
| 2 | `cd_dispatch` | cliente |
| 3 | `qs-dispatch` | cliente |
| 4 | `rcore_dispatch` | cliente |
| 5 | `core_dispatch` | servidor |
| 6 | `tk_dispatch` | cliente |
| 7 | `origen_police` | cliente |
| 8 | `lb-tablet` | servidor |
| 9 | `linden_outlawalert` | cliente |

Outras opções de `Config.Police.Dispatch`: `Code` (código de rádio, padrão `10-35`), `CodeName` (somente ps-dispatch), `Title` e `Message` (chaves de locale `dispatch_title` / `dispatch_message`; a mensagem recebe o modelo e a placa) e `Blip` (`Sprite`, `Color`, `Scale`, `Time` em segundos).

**Custom:** defina `System = 'custom'` e preencha `Editable.Client.DispatchAlert(data)` (`editable/client.lua`) e/ou `Editable.Server.DispatchAlert(data, source)` (`editable/server.lua`). `data` é `{ coords, plate, model, code, title, message, jobs, jobType }`; a versão do cliente recebe também `modelLabel` e `vehicle` (entidade).

## Chaves de veículo

Scripts de chaves (por exemplo `qbx_vehiclekeys`) não deixam o jogador ligar um veículo sem chaves. Após um lockpick bem-sucedido, o servidor entrega ao dono as chaves do veículo do trabalho, uma vez por trabalho e somente com um item de lockpick em mãos. Parceiros nunca recebem chaves.

`Config.VehicleKeys`:

| Opção | Comportamento |
| :--- | :--- |
| `System = 'auto'` | Primeiro script iniciado da lista abaixo. |
| `System = '<resource>'` | Força esse script (sem chaves se ele não estiver iniciado). |
| `System = 'custom'` | Chama `Editable.Server.GiveVehicleKeys(src, vehicle, plate, model)` e `Editable.Server.RemoveVehicleKeys(...)` em `editable/server.lua`. |
| `System = false` | Nenhuma chave é entregue (ESX sem script de chaves, por exemplo). |
| `RemoveOnEnd = true` | Retira as chaves quando o trabalho termina, antes de o veículo ser deletado. |

Scripts compatíveis, em ordem de detecção automática: `qbx_vehiclekeys`, `qs-vehiclekeys`, `wasabi_carlock`, `MrNewbVehicleKeys`, `ak47_vehiclekeys`, `vehicles_keys`, `qb-vehiclekeys`.

Não integrados (use `'custom'`): Renewed-Vehiclekeys, chaves do cd_garage, t1ger_keys, okokGarage / okokVehicleKeys.

## Categorias de veículo e loot

O servidor escolhe o veículo. `Config.Tiers` agrupa os modelos em categorias (`low`, `mid`, `high` por padrão):

| Campo | Descrição |
| :--- | :--- |
| `label` | Chave de locale (ou texto) exibida quando o trabalho começa. |
| `weight` | Chance relativa da categoria entre as que o jogador atende. |
| `minLevel` | Nível de reputação necessário. Ignorado quando a reputação está desativada. |
| `minPolice` | Opcional. Policiais em serviço necessários para esta categoria. |
| `payout` | Multiplicador do pagamento final (`Config.Payment`). |
| `quality` | Qualidade dada aos itens de peça desta categoria: `standard`, `premium` ou `exotic`. Itens de qualidades diferentes não empilham. |
| `models` | Nomes de modelo de veículo; um é escolhido ao acaso. |
| `loot` | Sorteios extras para cada peça removida: `{ item, chance (0-100), min, max, parts = { bones }, quality = true }`. |

- A categoria, o modelo e o loot são sorteados no servidor.
- Antes de remover uma peça, o servidor verifica se a peça, seus itens extras e todo o loot cabem de uma vez. Se não couberem, nada é entregue e a peça continua no carro.
- **Venda:** o ped de venda paga `price x QualityMultiplier[quality] x sellMultiplier da reputação` por cada pilha. Padrões de `Config.SellPed.QualityMultiplier`: standard 1.0, premium 1.5, exotic 2.5.
- Os itens que só saem como loot (`scrap_metal`, `sport_wheel`, `turbo_kit`) precisam estar registrados no seu inventário e constar em `Config.SellPed.Items` para poderem ser vendidos.
- Uma configuração que ainda tenha a antiga lista plana `Config.Vehicles` e não tenha `Config.Tiers` continua funcionando como uma única categoria `low`.

## Reputação

Guardada por personagem na tabela oxmysql `nek_chopshop_reputation` (`identifier`, `xp`, `jobs`, `last_job`), criada automaticamente. `identifier` é o id de personagem do framework (`identifier` no ESX, `citizenid` no QBCore/Qbox).

- **Ganho de XP (somente servidor):** um trabalho concluído dá ao dono `Base + PerPart x peças removidas + TimeBonusMax x (fração do tempo de desmanche que restava)`. O parceiro recebe `PartnerShare` (0-1) disso. Um trabalho fora do tempo ou com o veículo perdido custa ao dono `PenaltyExpired`; sair do servidor com um trabalho ativo custa `PenaltyAbandoned`. O XP nunca fica abaixo de 0.
- **Níveis** (`Config.Reputation.Levels`): a primeira entrada é o nível 0 (`xp = 0`). Cada nível lista seus próprios bônus:

| Bônus | Efeito |
| :--- | :--- |
| `sellMultiplier` | Multiplica o preço do ped de venda (além do multiplicador de qualidade). |
| `cooldownMultiplier` | Multiplica `Config.Cooldown` ao pegar um trabalho (0-1). |
| `extraPartChance` | Chance (0-100) de uma cópia extra de cada peça removida. |
| categorias de veículo | Liberadas por `Config.Tiers[].minLevel` (padrão: média no nível 2, alta no nível 4). |

- **Decaimento** (`Config.Reputation.Decay`, desativado por padrão): cada semana completa sem um trabalho concluído remove `PerWeek` de XP. É calculado quando a reputação é lida; não há temporizador.
- **Desativada** (`Enabled = false`): sem XP, sem bônus, todas as categorias disponíveis, sem SQL.
- O quadro mostra o nível e o progresso; uma subida de nível envia uma notificação e, com `Config.Logs.EnableReputation`, um log no Discord.

## Peças

Entradas de `Config.ChopParts`: `bone`, `part` (índice de porta ou roda), `item`, `label` (chave de locale), `isDoor` / `isWheel`, `bonus` (itens extras), `anim` (`'repair'` para a animação sob o capô), `optional` e `requires`.

- Peças padrão: 4 portas, capô (dá `car-battery`), porta-malas, motor (exige remover o capô), 2 bancos dianteiros (exigem remover a porta correspondente) e 4 rodas.
- Somente as 4 rodas são obrigatórias. Todas as outras peças são opcionais: fazem parte do trabalho apenas se o modelo do veículo tiver aquele osso, de modo que um modelo sem um osso nunca deixa o trabalho impossível de concluir.
- `requires` é aplicado no servidor. Se a peça exigida não faz parte do trabalho, o requisito conta como cumprido.

## Idiomas

Todo o texto visível ao jogador fica em `locales/<lang>.json`, carregado com o módulo de locale do ox_lib.

Incluídos: inglês (`en`), espanhol (`es`), francês (`fr`), alemão (`de`), italiano (`it`), português do Brasil (`pt-br`), polonês (`pl`), holandês (`nl`), turco (`tr`) e tcheco (`cs`).

- **Trocar de idioma:** adicione `setr ox:locale "pt-br"` ao `server.cfg` (padrão `en`). Os jogadores também podem escolher o idioma no menu de configurações do ox_lib; a NUI é atualizada quando o fazem.
- **Contingência:** uma chave ausente usa o inglês; um arquivo ausente usa o inglês.
- **Adicionar um idioma:** copie `locales/en.json` para `locales/<code>.json` (mesmo código de `ox_lib/locales`, por exemplo `ru`, `zh-cn`), traduza os valores e mantenha as chaves. Mantenha `%s` / `%d` na mesma ordem e os `{placeholders}` da seção `nui` inalterados. Não use `${...}` dentro dos textos.
- Não edite `ChopLocale` / `LoadChopLocale` na configuração.

## Administração

| Comando | Descrição |
| :--- | :--- |
| `chopshop_resetcd all` | Limpa o cooldown de trabalho de todos os personagens e licenças. |
| `chopshop_resetcd <player id>` | Limpa o cooldown de um jogador conectado (personagem atual e licença). |
| `chopshopui` | Comando de jogador: fecha todas as telas da NUI e libera o foco do mouse caso um erro da página o deixe preso. |

Os cooldowns ficam no armazenamento KVP deste recurso (a pasta `db/` do servidor), não no MySQL.

`Config.AdminAce` (padrão `'admin'`):

- Jogadores com este ACE podem executar `chopshop_resetcd` no jogo (o ACE `command.chopshop_resetcd` também serve). O console do servidor sempre pode executá-lo.
- Jogadores com este ACE ignoram a verificação anti-teletransporte da entrega, para que a equipe possa testar com teletransportes.

```cfg
add_ace group.admin admin allow
```

## Exports

Use o nome da pasta do recurso em `exports[...]`.

### Cliente

```lua
-- Retorna { active = boolean, pedCoords = vector4 }
-- active: o jogador local tem um trabalho de desmanche ativo. pedCoords: Config.Ped.Coords.
local status = exports.nek_chopshop:GetJobStatus()
if status.active then
    print('Working on a chop job')
end
```

### Servidor

```lua
-- GetReputation(identifier: string) -> { xp = number, level = number, jobs = number } | nil
-- nil quando a reputação está desativada, o identificador é inválido ou o banco de dados não pôde ser lido.
-- Pode esperar pelo banco de dados na primeira vez que um identificador é lido: chame a partir de uma thread.
CreateThread(function()
    local rep = exports.nek_chopshop:GetReputation(citizenid)
    if rep then print(rep.xp, rep.level, rep.jobs) end
end)

-- AddReputation(identifier: string, amount: number, reason?: string) -> boolean
-- amount: diferente de zero; positivo soma e negativo subtrai (frações são truncadas, máximo 1000000).
-- reason: texto para o log (cortado em 100 caracteres, padrão 'export').
-- Salvo de forma assíncrona, impresso no console e registrado no Discord (Config.Logs.EnableReputation).
-- Retorna false para identificador ou quantidade inválidos, quando a reputação está desativada ou quando a
-- linha não pôde ser lida (a alteração fica na fila e é aplicada uma vez na próxima leitura bem-sucedida).
-- Pode esperar pelo banco de dados na primeira vez que um identificador é usado: chame a partir de uma thread.
CreateThread(function()
    exports.nek_chopshop:AddReputation(citizenid, 50, 'event reward')
    exports.nek_chopshop:AddReputation(citizenid, -25, 'admin correction')
end)
```

## Funções editáveis

Estes arquivos foram feitos para serem editados:

| Arquivo | Função | Finalidade |
| :--- | :--- | :--- |
| `editable/server.lua` | `Editable.Webhook` | URL do webhook do Discord. |
| `editable/server.lua` | `Editable.Server.SendDiscordLog(title, description, color)` | Envio de logs personalizado. |
| `editable/server.lua` | `Editable.Server.CustomReward(source)` | Recompensa extra ao concluir um trabalho (cripto, XP, itens...). |
| `editable/server.lua` | `Editable.Server.DispatchAlert(data, source)` | Despacho personalizado (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Server.GiveVehicleKeys` / `RemoveVehicleKeys` | Chaves personalizadas (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Inventory` | Adaptador de inventário personalizado (`Config.Inventory = 'custom'`). |
| `editable/client.lua` | `Editable.Client.MiniGame()` | Minigame do lockpick; retorne `true` em caso de sucesso. Padrão `lib.skillCheck`. |
| `editable/client.lua` | `Editable.Client.DispatchAlert(data)` | Despacho personalizado no cliente do ladrão. |
| `editable/client.lua` | `Editable.Client.Notify(data)` | Estilo de notificação (usado quando a NUI está desativada ou não está pronta). |

Cada função traz exemplos comentados e o formato exato dos seus argumentos.

## Personalização da NUI

A NUI fica em `web/` (Web Components simples, sem etapa de build). O lado Lua e a página compartilham um único contrato: [web/CONTRACT.md](../../web/CONTRACT.md) (mensagens, callbacks, payloads das telas, chaves de locale).

- **Cores, fontes, espaçamento e posição** são variáveis CSS em `web/styles/tokens.css`: cores de papel e tinta (`--paper-original`, `--ink`, `--stamp`...), fontes (`--font-print`, `--font-hand`, `--font-num`) e a posição da ficha do trabalho (`--tracker-top`, `--tracker-right`).
- **Os textos** vêm da seção `nui` de `locales/<lang>.json`.
- `Config.UseNUI = false` remove a NUI e usa menus e notificações do ox_lib.

## Itens e ícones

Cada peça, item extra, recompensa final e item de loot de categoria é verificado na lista de itens do inventário ao iniciar e sempre que o inventário reinicia (ignorado se o inventário não tiver um export com a lista de itens). Entradas de loot desconhecidas são descartadas com um aviso no console; peças, itens extras e recompensas desconhecidos apenas são reportados.

| Item | Origem |
| :--- | :--- |
| `vehicle_door`, `vehicle_hood`, `vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `veh_wheels` | Peças |
| `car-battery` | Extra do capô |
| `veh_suspension` | `Config.FinishReward` padrão |
| `scrap_metal`, `sport_wheel`, `turbo_kit` | Loot de categoria |

Os ícones ficam em `[assets]`, com o nome do seu item. Vêm da galeria de imagens RAINMAD (https://items.rainmad.com/).

## Solução de problemas

| Problema | Causa e solução |
| :--- | :--- |
| `No such export getSharedObject in resource es_extended` (ou similar) | `Config.Framework` está forçado para um framework que não está iniciado. Use `'auto'`. Desde a 2.0.0, um framework forçado que não está iniciado volta para a detecção automática e imprime um aviso. |
| `... item "x" is not registered in <inventory>` no console | O item não existe no seu inventário. Adicione-o a partir de [docs/items](../items/). |
| `No supported inventory detected` | Nenhum inventário da lista está iniciado. Inicie-o antes do nek_chopshop, ou use `'custom'`. |
| O jogador fica sem chaves após o lockpick | Verifique `Config.VehicleKeys.System`: seu script de chaves pode não ser compatível (use `'custom'`) ou não estar iniciado. |
| Sem alerta à polícia | Verifique `Config.Police.Dispatch.System`: o script pode não estar iniciado ou não ser compatível (use `'custom'`). |
| "Not enough police on duty" | `Config.Police.MinOnDuty` (ou o `minPolice` da categoria) é maior que o número de policiais em serviço. Defina `0` para desativar. |
| "You have to wait N minutes before working again." | Cooldown do trabalho. A equipe pode executar `chopshop_resetcd <id>` ou `chopshop_resetcd all`. |
| "Nobody drives here that fast. Wait N s and try again." | A verificação anti-teletransporte rejeitou uma entrega mais rápida que `Config.Security.MaxAverageSpeed`. Aguarde os segundos indicados. A equipe com `Config.AdminAce` ignora a verificação. |
| O mouse fica na tela | Execute `/chopshopui`. |
| `Could not check for updates.` | O servidor não consegue acessar o GitHub. É inofensivo. |
| Erros da tabela de reputação | O oxmysql não está funcionando. Verifique a string de conexão dele. |

Defina `Config.Debug = true` para ter mais saída no console.

Nota: as mensagens citadas são os textos em inglês; no jogo elas aparecem no idioma configurado.

## Atualizando da v1

Mudanças incompatíveis:

- **Itens:** 6 itens novos (`vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `scrap_metal`, `sport_wheel`, `turbo_kit`). Registre-os e copie suas imagens (veja "Instalação").
- **Imagem renomeada:** `[assets]/vehicle_wheel.png` agora é `[assets]/veh_wheels.png` (o nome do item `veh_wheels` não mudou). Renomeie-a nas imagens do seu inventário se você copiou a antiga.
- **Locales:** `Config.Locales` foi removido. Os textos foram para `locales/*.json` (ox_lib). Se você editou textos, copie-os para o seu arquivo de idioma.
- **Veículos:** a lista plana `Config.Vehicles` virou `Config.Tiers` (a lista antiga continua funcionando como uma categoria `low`).
- **Novas seções de configuração:** `Config.Inventory`, `Config.Police`, `Config.VehicleKeys`, `Config.TimeLimit`, `Config.Reputation`, `Config.Tiers`, `Config.AdminAce`, `Config.UseNUI`, `Config.SellPed.QualityMultiplier`. `Config.Framework` agora é `'auto'` por padrão. Mescle-as a partir do novo `shared/config.lua`.
- **Funções editáveis:** `Editable.Client.DispatchAlert` agora recebe uma tabela `data` em vez do veículo (`data.vehicle` é a entidade). Novas funções: `Editable.Server.DispatchAlert`, `Editable.Server.GiveVehicleKeys`, `Editable.Server.RemoveVehicleKeys`, `Editable.Inventory`.
- **Dependências:** `oxmysql` agora é obrigatório. `ox_inventory` deixou de ser obrigatório.
- **Exports:** o export de cliente é `exports.nek_chopshop:GetJobStatus()` (use o nome real da pasta do recurso); novos exports de servidor `GetReputation` e `AddReputation`.

Faça backup do seu `shared/config.lua` e dos arquivos de `editable/` antes de substituir o recurso e reaplique suas alterações sobre os arquivos novos. Lista completa de mudanças: [CHANGELOG.md](../../CHANGELOG.md).

## Documentação em outros idiomas

- [English](../../README.md)
- [Español](README.es.md)
- [Français](README.fr.md)
- [Deutsch](README.de.md)

## Licença

Proprietária, com código visível. Você pode usá-lo nos seus servidores, modificá-lo e fazer forks do repositório; não pode vendê-lo, reenviá-lo nem redistribuí-lo fora de um fork. Termos completos (em inglês) em [LICENSE](../../LICENSE).
