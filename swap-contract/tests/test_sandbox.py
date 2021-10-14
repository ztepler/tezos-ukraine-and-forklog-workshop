from pytezos.sandbox.node import SandboxedNodeTestCase
from pytezos import ContractInterface, pytezos


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


class ContractInteractionsTestCase(SandboxedNodeTestCase):

    def _deploy_token(self):
        token = CONTRACTS['token'].using(
            shell=self.get_node_url(),
            key=self.manager.key)

        # Привязываем выпущенный токен к публичному ключу аккаунта используемого
        # для тестов:
        token_storage = TOKEN_STORAGE
        token_storage['ledger'].update({5: self.manager.key.public_key_hash()})

        opg = token.originate(initial_storage=TOKEN_STORAGE).send()
        self.bake_block()

        opg = self.manager.shell.blocks['head':].find_operation(opg.hash())
        op_result = opg['contents'][0]['metadata']['operation_result']
        address = op_result['originated_contracts'][0]
        self.token = self.manager.contract(address)


    def _deploy_swap(self):
        swap = CONTRACTS['swap'].using(
            shell=self.get_node_url(),
            key=self.manager.key)

        initial_storage = {
            'swaps': {},
            'token_address': self.token.address,
            'metadata': {}
        }

        opg = swap.originate(initial_storage=initial_storage).send()
        self.bake_block()

        opg = self.manager.shell.blocks['head':].find_operation(opg.hash())
        op_result = opg['contents'][0]['metadata']['operation_result']
        address = op_result['originated_contracts'][0]
        self.swap = self.manager.contract(address)


    def setUp(self):
        self.manager = self.client.using(key='bootstrap1')
        self.manager.reveal()

        self._deploy_token()
        self._deploy_swap()


    def test_integration_list_accept(self):
        update_operators_param = [{'add_operator': {
            'owner': self.manager.key.public_key_hash(),
            'operator': self.swap.address,
            'token_id': 5
        }}]

        self.token.update_operators(update_operators_param).send()
        self.bake_block()

        self.swap.list({'token_id': 5, 'ask_price': 10_000_000}).send()
        self.bake_block()

        # Проверка что токен теперь на своп контракте:
        self.assertTrue(
            self.token.storage['ledger'][5](),
            self.swap.address
        )

        self.swap.accept(5)
        self.bake_block()

        # Проверка что токен вернулся обратно на аккаунт менеджера:
        self.assertTrue(
            self.token.storage['ledger'][5](),
            self.manager.key.public_key_hash()
        )

