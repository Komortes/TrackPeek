# Приватная доска TrackPeek

[TrackPeek — private workbench](https://github.com/users/Komortes/projects/4)
принадлежит `Komortes`. Репозиторий `Komortes/TrackPeek` публичный; внутренние
идеи, задачи и баги хранятся как **DraftIssue** внутри приватного Project.
Конфигурация подключения — [.github/agent-board.json](../../.github/agent-board.json).

Приватность Project не делает приватными issues публичного репозитория.
Не превращай внутренний draft в issue ради полей Repository или Linked pull requests.
Для PR есть отдельное текстовое поле. В коммитах остаются правила, шаблоны и
код; приватные тела карточек, exports и handoff — на доске и в игнорируемом
`.agent-work/`. Не запускай загрузку приватной доски в публичном CI.

## Поля и виды

| Поле | Значение |
| --- | --- |
| Status | Backlog, Ready, In progress, Review, Blocked, Done |
| Kind | Idea, Feature, Task, Bug |
| Approval | Draft, Needs approval, Approved, Declined; согласование новой фичи |
| Approval evidence | Кто и когда подтвердил какую версию/границы; цитата или ссылка на исходное согласие |
| Priority | P1 — сначала, P2 — обычная очередь, P3 — позже |
| Area | UI, Core, Native, Tooling, Docs, Release |
| Agent | Текущий исполнитель или координатор |
| Next action | Одно конкретное действие и его владелец |
| Work link | Рабочая сессия или ветка |
| PR | Ссылка на реально созданный PR |
| Evidence | Проверяемая версия, результаты команд/review, ограничения |

Основной вид «Поток» — доска исполнения по `Status` для `Kind:Task,Bug,Feature`.
«Идеи» — таблица `Kind:Idea,Feature` с видимым `Approval`. Отдельные сохранённые
представления «Черновики», «На согласовании» и «Одобренные фичи» показывают
соответственно Draft, Needs approval и Approved. Это отделяет продуктовое решение
от стадии исполнения; одобренная фича может ещё оставаться в Backlog.
Другие виды показывают задачи, баги, готовую работу и элементы, которым нужно внимание.
Состояние карточек хранится только на доске; [BACKLOG.md](BACKLOG.md) служит
указателем, а не второй очередью.

Карточка содержит основание, ожидаемый результат, границы, несколько критериев
приёмки, зависимости и проверки. Для бага нужны шаги воспроизведения либо явная
пометка, что это гипотеза или пробел проверки. Для идеи — польза и открытые вопросы.
Условия переходов описаны в [LOOP.md](LOOP.md).

## Согласование новой фичи

| Approval | Смысл | Допустимый следующий шаг |
| --- | --- | --- |
| Draft | Черновая идея с непроверенными предположениями | Агент исследует пользу, ограничения и существующий код |
| Needs approval | Конкретное предложение готово к решению пользователя | Пользователь принимает, отклоняет или уточняет версию предложения |
| Approved | Пользователь явно подтвердил описанную версию и границы | Координатор проверяет приёмку и зависимости перед Ready |
| Declined | Пользователь отклонил предложение | Сохранить решение; не реализовывать и не возвращать в очередь автоматически |

Черновик и предложение остаются `Kind:Idea`, `Status:Backlog`. В карточке укажи
целевого пользователя, проблему, минимальное поведение, исключения, критерии
приёмки, зависимости, предположения и версию предложения. Перед подтверждением
покажи пользователю именно этот проверяемый объём.

После явного согласия переведи **ту же карточку** в `Kind:Feature`, `Approval:Approved`.
Запиши в `Approval evidence` автора решения, дату, дословное подтверждение или ссылку
на исходное сообщение, версию и согласованные границы. Сохраняй это внутри приватной
доски. Одобрение само по себе не меняет `Status:Backlog` на `Ready`: ещё нужны понятная
приёмка, доступные зависимости и поручение на реализацию. Существующие идеи
без такого согласия остаются неутверждёнными; исторический roadmap не заменяет решение.

Координатор не может одобрить собственное предложение от имени пользователя.
Общее «продолжай», высокий приоритет, перенос карточки в Ready и рекомендация агента
не разрешают реализацию новой фичи. Не переименовывай её в Task/Bug для обхода проверки.
Исправления существующего поведения и обслуживание выполняются в пределах своего
действующего поручения, без отдельного продуктового согласования.

При расширении объёма обнови версию предложения, верни `Approval:Needs approval`
и останови зависящую от расширения реализацию. Сохрани прежнее согласие как историю,
добавь новый запрос решения; не подменяй его старой цитатой. Отзыв согласия также
останавливает реализацию. Перед назначением и возобновлением сверяй карточку
с исходным решением пользователя, а не только с заполненными полями.

## Читать и выбирать

Нужны `gh` с доступом к этому Project и настроенная авторизация. Не записывай
токены в конфигурацию или карточки.

```sh
./script/agent.sh board
./script/agent.sh next
./script/agent.sh show ITEM_ID
```

`board` выводит краткий список со статусом согласования. `next` выбирает
неархивную `Ready` Task/Bug либо Feature и экспортирует приватный brief
в `.agent-work/current.md`. Feature проходит отбор только при `Approval:Approved`
и непустом `Approval evidence`. Task/Bug без полей согласования выбираются как раньше;
при наличии хотя бы одного такого поля к ним применяется та же проверка. Idea
не выбирается никогда, даже с Approved и Ready. Отсутствующее, неизвестное или
неполное согласование не считается одобрением.

Это проверка метаданных, а не проверка личности или полномочий автора решения.
Координатор обязан проверить фактическое явное согласие пользователя и его границы.
`show` читает любой указанный приватный draft, включая неодобренные идеи; чтение
не разрешает реализацию. Команды только читают GitHub. Снимок не является
назначением, актуальной блокировкой или доказательством завершения.
У `next` код 3 означает отсутствие подходящей задачи; сохранённый прежний brief
в этом случае не исполняется. Ошибки чтения возвращают 1, ошибки аргументов — 2.

Чтобы перенести подготовленный локальный черновик на доску, сначала проверь
доступ и приватность командой `board`, затем создай именно draft:

```sh
./script/agent.sh board &&
gh project item-create 4 --owner Komortes --title 'Короткая цель' \
  --body "$(cat .agent-work/tasks/YYYY-MM-DD-short-description.md)"
```

Заполни Kind, Priority, Status и Next action через поля проекта. Для новой идеи
также задай `Approval:Draft`; `Approval evidence` оставь пустым до реального решения.
Сначала Backlog; перевод в Ready требует условий из LOOP.md и согласования фичи.
Не используй `gh issue create` для внутренних карточек публичного репозитория.

## Занять и обновить карточку

Статусы записывает один координатор. GitHub Projects не предоставляет атомарное
занятие карточки: порядок ниже — договорённость, не межпроцессный lock.
Перед работой прочитай карточку, проверь согласование фичи и отсутствие другого
владельца; после записи перечитай её. При конфликте не начинай конкурирующую реализацию.

Для Bash задай `TP_ITEM_ID` из вывода `board`/`next`, `TP_AGENT`, `TP_WORK_LINK` и `TP_NEXT_ACTION`
конкретной итерации. Затем выполни блок целиком. Идентификаторы проекта, полей
и опций читаются из GitHub; их нельзя угадывать или переносить из другого Project.

```sh
(
  set -euo pipefail
  : "${TP_ITEM_ID:?Set the actual item ID from agent.sh board}"
  : "${TP_AGENT:?Set the current coordinator or agent}"
  : "${TP_WORK_LINK:?Set the actual branch or working session}"
  : "${TP_NEXT_ACTION:?Set the concrete next action and owner}"
  test "$(gh project view 4 --owner Komortes --format json --jq '.public')" = false
  tp_project_id="$(gh project view 4 --owner Komortes --format json --jq '.id')"
  tp_status_field="$(gh project field-list 4 --owner Komortes --format json --jq '.fields[] | select(.name == "Status") | .id')"
  tp_agent_field="$(gh project field-list 4 --owner Komortes --format json --jq '.fields[] | select(.name == "Agent") | .id')"
  tp_next_field="$(gh project field-list 4 --owner Komortes --format json --jq '.fields[] | select(.name == "Next action") | .id')"
  tp_work_field="$(gh project field-list 4 --owner Komortes --format json --jq '.fields[] | select(.name == "Work link") | .id')"
  tp_status_option="$(gh project field-list 4 --owner Komortes --format json --jq '.fields[] | select(.name == "Status") | .options[] | select(.name == "In progress") | .id')"
  test -n "$tp_status_field" && test -n "$tp_agent_field"
  test -n "$tp_next_field" && test -n "$tp_status_option"
  test -n "$tp_work_field"
  gh project item-edit --id "$TP_ITEM_ID" --project-id "$tp_project_id" --field-id "$tp_agent_field" --text "$TP_AGENT"
  gh project item-edit --id "$TP_ITEM_ID" --project-id "$tp_project_id" --field-id "$tp_next_field" --text "$TP_NEXT_ACTION"
  gh project item-edit --id "$TP_ITEM_ID" --project-id "$tp_project_id" --field-id "$tp_work_field" --text "$TP_WORK_LINK"
  gh project item-edit --id "$TP_ITEM_ID" --project-id "$tp_project_id" --field-id "$tp_status_field" --single-select-option-id "$tp_status_option"
  ./script/agent.sh show "$TP_ITEM_ID"
)
```

После успешного выполнения **прочитай** `.agent-work/current.md`: Agent,
Next action и статус должны соответствовать этой итерации. При частичном сбое
перечитай реальное состояние перед повтором: эти изменения не являются транзакцией.

Для перехода в `Review`, `Blocked` или `Done` прочитай ID нужной опции `Status`
тем же способом, предварительно запиши новый `Next action` и доказательства.
Текстовые поля `Work link`, `PR`, `Evidence` обновляются через `item-edit --text`
с field ID из `gh project field-list`. Для многострочного evidence подготовь
локальный файл в `.agent-work/` и передай содержимое как один аргумент:
`--text "$(cat .agent-work/evidence.md)"`. Не подставляй текст карточки в shell-код.

Статус Done ставится по приёмке [цикла](LOOP.md), а не по факту экспорта карточки
или успешного запуска команды. Подготовка доски не включает автопубликацию
или автоматическую реализацию всех её элементов.

Справка: [видимость Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/managing-visibility-of-your-projects),
[gh project item-edit](https://cli.github.com/manual/gh_project_item-edit).
