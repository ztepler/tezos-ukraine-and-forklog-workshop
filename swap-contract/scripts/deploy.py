from pytezos import ContractInterface, pytezos
import time


SHELL = 'https://granadanet.smartpy.io/'
KEY_FILENAME = 'key.json'
CONTRACTS = {
    'token': ContractInterface.from_file('build/token.tz'),
    'swap': ContractInterface.from_file('build/swap.tz')
}

# В сторадже токена подготовлен один NFT объект:
TOKEN_STORAGE = {
    "ledger": {
        5: "tz1S6V1YfUqt7facXpdk68JQ11mD8qUh5Yex"
    },
    "metadata": {
        "": "68747470733a2f2f676973742e67697468756275736572636f6e74656e742e636f6d2f7a7465706c65722f37356566643933323436363964336536663836343636363537353537336666322f7261772f336332643363386634656364336432613265343064623364373863393131393066366139346433662f636f6e74726163745f6d6574612e6a736f6e"
    },
    "operators": {},
    "token_metadata": {
        5: (
            5,
            {
                "": "68747470733a2f2f676973742e67697468756275736572636f6e74656e742e636f6d2f7a7465706c65722f32633135373665616133643765633134376665396535343938626661353264332f7261772f303765656130653836613366363234656436326662343030313834333537336139383932333133652f6e66745f6d6574612e6a736f6e"
            }
        )
    }
}


# Адрес токена определяется после деполя контракта с токеном:
SWAP_STORAGE = {
    "token_address": None,
    "swaps": {},
    "metadata": {
        "": "68747470733a2f2f676973742e67697468756275736572636f6e74656e742e636f6d2f7a7465706c65722f34323763313234646337613838306237316566336262663937356237643364362f7261772f366463323837623038303732616539316464636335616566623632383937303166653536306430312f737761705f6d6574612e6a736f6e"
    }
}


def activate_and_reveal(client):
    print(f'activating account...')
    op = client.activate_account().send()
    client.wait(op)

    op = client.reveal().send()
    client.wait(op)


def deploy_token(client):
    print(f'deploying token...')
    contract = CONTRACTS['token'].using(key=KEY_FILENAME, shell=SHELL)
    opg = contract.originate(initial_storage=TOKEN_STORAGE).send()
    print(f'success: {opg.hash()}')
    client.wait(opg)

    # Получаем адрес токена:
    opg = client.shell.blocks['head':].find_operation(opg.hash())
    op_result = opg['contents'][0]['metadata']['operation_result']
    address = op_result['originated_contracts'][0]
    print(f'token address: {address}')
    return address


def deploy_swap(client, address):
    print(f'deploying swap...')
    contract = CONTRACTS['swap'].using(key=KEY_FILENAME, shell=SHELL)

    storage = SWAP_STORAGE.copy()
    storage.update({'token_address': address})

    opg = contract.originate(initial_storage=storage).send()
    print(f'success: {opg.hash()}')


if __name__ == '__main__':

    client = pytezos.using(key=KEY_FILENAME, shell=SHELL)

    """
    1. Если ключ раньше не использовался, следующая функция позволит
    активировать аккаунт:
    """
    if client.balance() < 1e-5:
        activate_and_reveal(client)

    """
    2. Деплой токена
    """
    token_address = deploy_token(client)

    """
    3. Деплой swap контракта
    """
    deploy_swap(client, token_address)

