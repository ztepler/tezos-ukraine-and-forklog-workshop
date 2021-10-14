from pytezos import pytezos, ContractInterface, MichelsonRuntimeError
import pytest


SWAP_FN = 'build/swap.tz'

def test_should_transfer_when_list_called():
    contract = ContractInterface.from_file(SWAP_FN)

    init_storage = {
        'swaps': {5: {
            'ask_price': 500_000,
            'owner': 'tz1ZKZSGSqDkkEcJNdLMZANtTHZ3GTqKrddW'
        }},
        'token_address': 'KT1A2smYFA2zkGcji868B435oMAL1NCKRgMo',
        'metadata': {}
    }

    with pytest.raises(MichelsonRuntimeError) as err:
        result = contract.accept(12).interpret(storage=init_storage)
    assert 'Swap not found' in str(err)


