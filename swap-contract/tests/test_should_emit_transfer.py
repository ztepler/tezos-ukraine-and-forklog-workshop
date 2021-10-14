from pytezos import pytezos, ContractInterface


SWAP_FN = 'build/swap.tz'

def test_should_transfer_when_list_called():
    contract = ContractInterface.from_file(SWAP_FN)

    init_storage = {
        'swaps': {},
        'token_address': 'KT1A2smYFA2zkGcji868B435oMAL1NCKRgMo',
        'metadata': {}
    }

    list_params = {
        'ask_price': 1_000_000,
        'token_id': 5
    }

    result = contract.list(list_params).interpret(storage=init_storage)

    assert len(result.operations) == 1
    op = result.operations[0]
    assert op['parameters']['entrypoint'] == 'transfer'
    assert op['destination'] == init_storage['token_address']

