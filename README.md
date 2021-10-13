# Воркшоп: тестирование смарт-контрактов и разработка интерфейсов dapp

В данном репозитории содержатся материалы используемые для [WORKSHOP: тестирование смарт контрактов и разработка интерфейсов dapps](https://www.youtube.com/watch?v=yQ63nE_l2rE). Воркшоп проводится в рамках курса [Блокчейн-разработка на Tezos](https://forklog.com/sp/dev-on-tezos/)

Для работы по материалам воркшопа необходимо иметь установленный python3 и node.js + npm.
Также рекомендуется ознакомиться с процессом установки pytezos, для него требуется ряд дополнительных библиотек в ОС:
https://pytezos.org/quick_start.html

## Подготовка к написанию тестов:
1. Установка pytezos: [документация](https://pytezos.org/quick_start.html)
- если в системе не установлены библиотеки, необходимые для запуска pytezos, их нужно установить: `libsodium-dev libsecp256k1-dev libgmp-dev`
- создание виртуальной среды для работы и установка pytezos:
```console
python -m virtualenv env
source env/bin/activate
pip install pytezos pytest
```

2. Получение ключа с xtz в тестовой сети Granada:
- Необходимо зайти на портал https://faucet.tzalpha.net/ и получить новый ключ для работы с тестовой сетью (Get Testnet ꜩ )
- Скачать ключ в `json` формате, переименовать в `key.json` и переместить в директорию `swap-contract`

3. Для деполя токена и своп контракта в тестовой сети Granada, из директории `swap-contract` запускается скрипт:
```console
cd swap-contract
python scripts/deploy.py
```

## Подготовка к написанию UI:
1. Создать проект с использованием `create-react-app` с поддержкой TypeScript:
```console
npx create-react-app swap-app --template typescript
cd swap-app
```

2. Установить необходимые библиотеки для взаимодействия с Tezos:
```console
npm i @taquito/taquito @taquito/beacon-wallet
```

## Компиляция контрактов:
Для выполнения задания и компиляции контрактов необходимо запустить скрипт `./scripts/compile.sh` из директории `swap-contract`, для исполнения скрипта требуется docker.

---
NOTE: В предоставленном контракте есть уязвимости. Их обнаружение является частью задания по итогам воркшопа
---

