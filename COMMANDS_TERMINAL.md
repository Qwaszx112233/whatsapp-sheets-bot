# TERMINAL COMMANDS — WAPB (STAGE-BY-STAGE)

Пошаговая шпаргалка для работы с проектом из терминала VS Code / VS Code Insiders.

- **PowerShell 5.1**
- **без прав администратора**
- **cmd.exe заблокирован администратором**
- **Node portable**
- **PortableGit**
- **Google Apps Script через clasp**
- проект лежит в:

```text
C:\Users\User\Documents\whatsapp-sheets-bot
```

Node лежит в:

```text
C:\Users\User\Documents\node-v20.20.1-win-x64
```

Git лежит в:

```text
C:\Users\User\Documents\PortableGit
```

---

## Оглавление

1. [Что здесь главное](#1-что-здесь-главное)
2. [Этап 1 — открыть проект и терминал](#2-этап-1--открыть-проект-и-терминал)
3. [Этап 2 — подключить Node и Git в текущую сессию](#3-этап-2--подключить-node-и-git-в-текущую-сессию)
4. [Этап 3 — проверить, что пути реально живые](#4-этап-3--проверить-что-пути-реально-живые)
5. [Этап 4 — проверить версии Node / npm / npx / Git](#5-этап-4--проверить-версии-node--npm--npx--git)
6. [Этап 5 — создать короткие команды для работы](#6-этап-5--создать-короткие-команды-для-работы)
7. [Этап 6 — перейти в папку проекта](#7-этап-6--перейти-в-папку-проекта)
8. [Этап 7 — установить зависимости проекта](#8-этап-7--установить-зависимости-проекта)
9. [Этап 8 — подключить clasp](#9-этап-8--подключить-clasp)
10. [Этап 9 — проверить GitHub-подключение](#10-этап-9--проверить-github-подключение)
11. [Этап 10 — проверить подключение к GAS](#11-этап-10--проверить-подключение-к-gas)
12. [Этап 11 — открыть GAS-проект в браузере](#12-этап-11--открыть-gas-проект-в-браузере)
13. [Этап 12 — базовый рабочий цикл](#13-этап-12--базовый-рабочий-цикл)
14. [Этап 13 — если нужно сохранить изменения в GitHub](#14-этап-13--если-нужно-сохранить-изменения-в-github)
15. [Этап 14 — если нужно отправить изменения в GAS](#15-этап-14--если-нужно-отправить-изменения-в-gas)
16. [Этап 15 — полный боевой цикл](#16-этап-15--полный-боевой-цикл)
17. [Этап 16 — старт после перезапуска VS Code](#17-этап-16--старт-после-перезапуска-vs-code)
18. [Этап 17 — если что-то развалилось](#18-этап-17--если-что-то-развалилось)
19. [Что нельзя делать](#19-что-нельзя-делать)
20. [Короткая шпаргалка](#20-короткая-шпаргалка)

---

## 1. Что здесь главное

В этой системе нельзя опираться на обычные команды Windows-обёрток:

- `npm`
- `npx`
- `clasp.cmd`

Почему:

- у тебя **заблокирован `cmd.exe`**
- обычные Windows-обёртки часто идут именно через `*.cmd`
- из-за этого `node` работает, а `npm` может падать с сообщением:

```text
The command prompt has been disabled by your administrator.
```

Поэтому в этом проекте используется **правильный обходной путь**:

- `node.exe`
- `npm-cli.js`
- `npx-cli.js`
- `git.exe`

То есть не так:

```powershell
npm install
npx clasp status
```

А так:

```powershell
& $NODE $NPMCLI install
& $NODE $NPXCLI clasp status
```

Или через короткие функции:

```powershell
npmx install
npxx clasp status
```

---

## 2. Этап 1 — открыть проект и терминал

### Что делаем

1. Открываем **VS Code** или **VS Code Insiders**
2. Открываем папку проекта:

```text
C:\Users\User\Documents\whatsapp-sheets-bot
```

3. Открываем терминал **PowerShell**

### Команда проверки текущей версии PowerShell

```powershell
$PSVersionTable.PSVersion
```

### Что ожидаем

Для этого проекта **PowerShell 5.1 уже рабочий**.

---

## 3. Этап 2 — подключить Node и Git в текущую сессию

### Что делаем

Создаём переменные путей к реальным исполняемым файлам и CLI-скриптам.

### Полная формула этапа

```powershell
$NODE   = "C:\Users\User\Documents\node-v20.20.1-win-x64\node.exe"
$NPMCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npm-cli.js"
$NPXCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npx-cli.js"
$GIT    = "C:\Users\User\Documents\PortableGit\bin\git.exe"
```

### Что это значит

- `$NODE` — сам `node.exe`
- `$NPMCLI` — скрипт `npm`, запускаемый через `node`
- `$NPXCLI` — скрипт `npx`, запускаемый через `node`
- `$GIT` — реальный `git.exe`

---

## 4. Этап 3 — проверить, что пути реально живые

### Что делаем

Проверяем, что все указанные файлы действительно существуют.

### Полная формула этапа

```powershell
Test-Path $NODE
Test-Path $NPMCLI
Test-Path $NPXCLI
Test-Path $GIT
```

### Что ожидаем

Все четыре строки должны вернуть:

```text
True
```

Если хоть одна строка вернула `False`, значит путь указан неправильно.

---

## 5. Этап 4 — проверить версии Node / npm / npx / Git

### Что делаем

Проверяем, что инструменты реально запускаются.

### Полная формула этапа

```powershell
& $NODE -v
& $NODE $NPMCLI -v
& $NODE $NPXCLI --version
& $GIT --version
```

### Что ожидаем

Пример нормального результата:

```text
v20.20.1
10.8.2
10.8.2
git version 2.53.0.windows.2
```

---

## 6. Этап 5 — создать короткие команды для работы

### Что делаем

Чтобы не писать каждый раз портянки с `$NODE` и `$NPMCLI`, создаём функции.

### Полная формула этапа

```powershell
function npmx { & $NODE $NPMCLI @args }
function npxx { & $NODE $NPXCLI @args }
function gitx { & $GIT @args }
```

### Проверка

```powershell
npmx -v
gitx --version
```

### Что это даёт

Теперь можно писать:

```powershell
npmx install
npxx clasp --version
gitx status
```

вместо длинных команд.

---

## 7. Этап 6 — перейти в папку проекта

### Полная формула этапа

```powershell
Set-Location "C:\Users\User\Documents\whatsapp-sheets-bot"
```

или коротко:

```powershell
cd "C:\Users\User\Documents\whatsapp-sheets-bot"
```

### Проверка текущей папки

```powershell
Get-Location
```

---

## 8. Этап 7 — установить зависимости проекта

### Что делаем

Устанавливаем `node_modules` и зависимости из `package.json`.

### Полная формула этапа

```powershell
npmx install
```

### Что это делает

- читает `package.json`
- ставит зависимости
- создаёт или обновляет `node_modules`
- создаёт или обновляет `package-lock.json`

---

## 9. Этап 8 — подключить clasp

### Что делаем

Ставим `@google/clasp` как dev-зависимость проекта.

### Полная формула этапа

```powershell
npmx install --save-dev @google/clasp
```

### Проверка версии clasp

```powershell
npxx clasp --version
```

### Ожидаемый результат

Пример:

```text
3.3.0
```

---

## 10. Этап 9 — проверить GitHub-подключение

### Что делаем

Проверяем, что папка — это Git-репозиторий и что remote уже подключён.

### Полная формула этапа

```powershell
gitx status
gitx remote -v
```

### Что ожидаем

Пример нормального результата:

```text
On branch main
Your branch is up to date with 'origin/main'.
```

и:

```text
origin  https://github.com/... (fetch)
origin  https://github.com/... (push)
```

### Если remote ещё не подключён

```powershell
gitx remote add origin https://github.com/USERNAME/REPOSITORY.git
```

Проверка:

```powershell
gitx remote -v
```

---

## 11. Этап 10 — проверить подключение к GAS

### Что делаем

Проверяем наличие `.clasp.json` и состояние проекта Apps Script.

### Формула проверки файла `.clasp.json`

```powershell
Get-Content .clasp.json
```

### Что ожидаем

Пример:

```json
{
  "scriptId": "1AB7o3GPo41RchW5k_LAWrgwsIujcfNBQpvqHP5faLldTs0hFglbWI85_",
  "rootDir": ".",
  "scriptExtensions": [".gs"],
  "htmlExtensions": [".html"]
}
```

### Формула проверки статуса GAS

```powershell
npxx clasp status
```

### Если нужно войти в Google

```powershell
npxx clasp login
```

### Если нужно выйти и зайти заново

```powershell
npxx clasp logout
npxx clasp login
```

---

## 12. Этап 11 — открыть GAS-проект в браузере

### Полная формула этапа

```powershell
npxx clasp open-script
```

### Что это делает

Открывает привязанный Apps Script проект в браузере.

---

## 13. Этап 12 — базовый рабочий цикл

### Что делаем после открытия VS Code

```powershell
$PSVersionTable.PSVersion

$NODE   = "C:\Users\User\Documents\node-v20.20.1-win-x64\node.exe"
$NPMCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npm-cli.js"
$NPXCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npx-cli.js"
$GIT    = "C:\Users\User\Documents\PortableGit\bin\git.exe"

function npmx { & $NODE $NPMCLI @args }
function npxx { & $NODE $NPXCLI @args }
function gitx { & $GIT @args }

cd "C:\Users\User\Documents\whatsapp-sheets-bot"

npmx -v
gitx --version
npxx clasp --version
gitx status
npxx clasp status
```

---

## 14. Этап 13 — если нужно сохранить изменения в GitHub

### Что делаем

Фиксируем локальные изменения и отправляем их в GitHub.

### Полная формула этапа

```powershell
gitx add .
gitx commit -m "update"
gitx push
```

### Пример с нормальным сообщением

```powershell
gitx add .
gitx commit -m "fix send panel and sidebar state"
gitx push
```

### Проверка перед commit

```powershell
gitx status
```

---

## 15. Этап 14 — если нужно отправить изменения в GAS

### Что делаем

Отправляем локальные `.gs`, `.html`, `appsscript.json` в Google Apps Script.

### Полная формула этапа

```powershell
npxx clasp push
```

### Если нужно сначала подтянуть изменения из облака

```powershell
npxx clasp pull
```

### Важное правило

Если ты менял код **в редакторе GAS**, сначала делай:

```powershell
npxx clasp pull
```

Если ты менял код **локально в VS Code**, обычно делаешь:

```powershell
npxx clasp push
```

Иначе можно перетереть одно другим. Windows тупит, GAS тупит, а потом виноват почему-то пользователь. Классика жанра.

---

## 16. Этап 15 — полный боевой цикл

### Сценарий: локально поправил код, хочешь отправить и в GAS, и в GitHub

```powershell
$PSVersionTable.PSVersion

$NODE   = "C:\Users\User\Documents\node-v20.20.1-win-x64\node.exe"
$NPMCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npm-cli.js"
$NPXCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npx-cli.js"
$GIT    = "C:\Users\User\Documents\PortableGit\bin\git.exe"

function npmx { & $NODE $NPMCLI @args }
function npxx { & $NODE $NPXCLI @args }
function gitx { & $GIT @args }

cd "C:\Users\User\Documents\whatsapp-sheets-bot"

gitx status
npxx clasp status
npxx clasp push
gitx add .
gitx commit -m "update"
gitx push
```

---

## 17. Этап 16 — старт после перезапуска VS Code

### Важный момент

После закрытия PowerShell функции:

- `npmx`
- `npxx`
- `gitx`

исчезают.

То есть после нового запуска VS Code их надо создать заново.

### Быстрая формула старта новой сессии

```powershell
$NODE   = "C:\Users\User\Documents\node-v20.20.1-win-x64\node.exe"
$NPMCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npm-cli.js"
$NPXCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npx-cli.js"
$GIT    = "C:\Users\User\Documents\PortableGit\bin\git.exe"

function npmx { & $NODE $NPMCLI @args }
function npxx { & $NODE $NPXCLI @args }
function gitx { & $GIT @args }

cd "C:\Users\User\Documents\whatsapp-sheets-bot"
```

### Проверка после старта

```powershell
npmx -v
gitx --version
npxx clasp --version
gitx status
npxx clasp status
```

---

## 18. Этап 17 — если что-то развалилось

### 1. Проверка PowerShell

```powershell
$PSVersionTable.PSVersion
```

### 2. Проверка путей

```powershell
Test-Path $NODE
Test-Path $NPMCLI
Test-Path $NPXCLI
Test-Path $GIT
```

### 3. Проверка версий

```powershell
& $NODE -v
& $NODE $NPMCLI -v
& $NODE $NPXCLI --version
& $GIT --version
```

### 4. Проверка Git

```powershell
gitx status
gitx remote -v
```

### 5. Проверка GAS

```powershell
Get-Content .clasp.json
npxx clasp status
```

### 6. Перелогиниться в GAS

```powershell
npxx clasp logout
npxx clasp login
npxx clasp status
```

---

## 19. Что нельзя делать

### Нельзя

Нельзя слепо запускать:

```powershell
npm install
npx clasp status
```

если у тебя `cmd.exe` заблокирован.

Нельзя считать, что проблема в Node, если работает:

```powershell
node -v
```

а не работает:

```powershell
npm -v
```

В таком случае проблема обычно в Windows-обёртках `*.cmd`, а не в самом Node.

Нельзя забывать, что после закрытия терминала функции `npmx`, `npxx`, `gitx` исчезают.

Нельзя делать `clasp pull`, если у тебя есть важные локальные правки, которые ещё не сохранены. Иначе можно красиво выстрелить себе в ногу. Даже без автомата.

---

## 20. Короткая шпаргалка

```powershell
# === ПОДНЯТЬ СРЕДУ ===
$NODE   = "C:\Users\User\Documents\node-v20.20.1-win-x64\node.exe"
$NPMCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npm-cli.js"
$NPXCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npx-cli.js"
$GIT    = "C:\Users\User\Documents\PortableGit\bin\git.exe"

function npmx { & $NODE $NPMCLI @args }
function npxx { & $NODE $NPXCLI @args }
function gitx { & $GIT @args }

cd "C:\Users\User\Documents\whatsapp-sheets-bot"

# === ПРОВЕРКА ===
& $NODE -v
npmx -v
gitx --version
npxx clasp --version

# === GIT ===
gitx status
gitx add .
gitx commit -m "update"
gitx push

# === GAS ===
Get-Content .clasp.json
npxx clasp status
npxx clasp open-script
npxx clasp pull
npxx clasp push
```

---

## Финальное правило

Если не уверен, что делать, запускай по порядку:

```powershell
$PSVersionTable.PSVersion

$NODE   = "C:\Users\User\Documents\node-v20.20.1-win-x64\node.exe"
$NPMCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npm-cli.js"
$NPXCLI = "C:\Users\User\Documents\node-v20.20.1-win-x64\node_modules\npm\bin\npx-cli.js"
$GIT    = "C:\Users\User\Documents\PortableGit\bin\git.exe"

function npmx { & $NODE $NPMCLI @args }
function npxx { & $NODE $NPXCLI @args }
function gitx { & $GIT @args }

cd "C:\Users\User\Documents\whatsapp-sheets-bot"

npmx -v
gitx --version
npxx clasp --version
gitx status
npxx clasp status
```

Если это работает — окружение живо, Git жив, GAS жив, можно работать дальше.
