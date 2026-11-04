# Актуальный контекст TrackPeek

Обновлено: 2026-11-04. Подготовка начата на
`af4644bd7c0ef6551fc49385492fca3870007eef`; фактические текущие HEAD/ветку/diff
показывает `./script/agent.sh context`. Живая очередь находится на приватной доске,
не в этом публичном документе.

## Продукт и сборка

- В `project.yml`: версия **1.1, build 5**, Swift 6, deployment target macOS 14.
- Реализованы Spotify/Apple Music, menu bar, notch/Focus, desktop widgets,
  lyrics, shortcuts, выбор экрана, экономный режим и диагностика.
- Языки en/uk/ru; строки в `Sources/Resources/*.xcstrings`.
- Полная сборка — `project.yml` и generated Xcode project; `Package.swift` неполон.
  Внешняя зависимость Sparkle разрешается через Xcode.
- `script/ci.sh` — общая локальная/CI проверка; toolchain закреплён в
  [ci.yml](../../.github/workflows/ci.yml). Тестовые сборки используют ad-hoc подпись.
- Публикация build 5 записана в [историческом журнале](../../AUTONOMOUS_PROGRESS.md).
  Текущий latest release и установленный app при подготовке цикла не проверялись.

## Средства агентской работы

- [Приватная доска](BOARD.md) содержит DraftIssue; `.github/agent-board.json`
  хранит только идентификаторы подключения, без токенов и содержимого карточек.
- `script/agent.sh board|next|show` читает GitHub через `gh`. `next` возвращает 0
  при выборе, 3 при отсутствии подходящей Ready Task/Bug, 1 при ошибке чтения.
- Brief и локальные карточки хранятся в игнорируемом `.agent-work/`. Снимок
  не назначает исполнителя. В новом checkout этот локальный каталог отсутствует.
- [LOOP.md](LOOP.md) и [роли](prompts/coordinator.md) задают один проверяемый результат
  за запуск, независимое review и handoff. Фоновый планировщик не включён.
- `build_and_run.sh --help` и неверные аргументы теперь завершаются до `pkill`
  и сборки. Рабочие run/debug/logs/telemetry/verify по-прежнему интерактивны.

## Проверки подготовки — 2026-11-04

- `./script/agent.sh doctor` проходит в обычном PATH. Установлены Actionlint 1.7.12
  и ShellCheck 0.11.0; XcodeGen 2.45.4 уже был доступен.
- `PYTHONDONTWRITEBYTECODE=1 ./script/ci.sh checks` прошёл: 60 Python-тестов,
  shell/workflow lint, соответствие XcodeGen, 467 + 2 записей локализации,
  8 public-key signature checks. Лог: `.build/ci/checks/run.log`.
- Среда: macOS 26.2 arm64, Xcode 26.6 (17F113), Swift 6.3.3, Python 3.9.6.
- На живом Project проверены private/open, draft-типы и представления; `board`
  и `next` успешно прочитали очередь. Brief исключён из Git, режим файла — 600.
- Независимый review инструментов и процесса не нашёл блокирующих замечаний;
  рецензент отдельно выполнил 27 новых CLI-тестов. Проверены 85 локальных
  Markdown-ссылок и синтаксис shell-примеров в документации.
- App tests, universal Release и native UI в этой подготовке не перезапускались:
  изменения затрагивают инструменты и документацию, Swift-код не менялся.

Последняя историческая app-проверка от 2026-10-21: 274 функции / 334 выполнения
и universal Release. Это не результат текущего прогона. Аппаратные/OS/permission
сценарии требуют своей среды; build и mocks не подтверждают их прохождение.

## Продолжение

Прочитать [LOOP.md](LOOP.md), выполнить `./script/agent.sh next`, сверить карточку
с запросом и назначить исполнителя по [BOARD.md](BOARD.md). Готовый запрос —
в [руководстве](README.md). Детали работы и приёмки хранятся на доске.
Карта исходников — [CODE_MAP.md](CODE_MAP.md), Git/PR — [GIT_WORKFLOW.md](../GIT_WORKFLOW.md),
релиз — [RELEASING.md](../RELEASING.md). `SPEC.md` и старый журнал исторические.
