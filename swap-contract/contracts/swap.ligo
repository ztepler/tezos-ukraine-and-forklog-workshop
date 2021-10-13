(* Simple Swap interface: *)
type list_params is record [
    token_id : nat;
    ask_price : tez;
]

type entrypoint is
| List of list_params
| Cancel of nat
| Accept of nat

type swap_params is record [
    owner : address;
    ask_price : tez;
]

type swaps_ledger is big_map(nat, swap_params)

type swap_storage is record [
    token_address : address;
    swaps : swaps_ledger;
    metadata : big_map (string, bytes);
]

type return is (list (operation) * swap_storage)

(* FA2 transfer interface:
    NOTE: можно организовать код так чтобы и token.ligo и swap.ligo использовали
    общий код в котором описан интерфейс для работы с FA2 токенами
    Для этого используется синтаксис #include
*)
type transfer_destination is
[@layout:comb]
record [
    to_ : address;
    token_id : nat;
    amount : nat;
]

type transfer is
[@layout:comb]
record [
    from_ : address;
    txs : list(transfer_destination);
]

type list_of_transfers is list(transfer)

(* FA2 one NFT token transfer: *)
function transfer_token(
    const token_address : address;
    const token_id : nat;
    const address_from : address;
    const address_to : address
) : operation is block {

    const token_entrypoint =
        case (Tezos.get_entrypoint_opt("%transfer", token_address)
            : option(contract(list_of_transfers))) of
        | None -> (failwith("No FA2 token found") : contract(list_of_transfers))
        | Some(entry) -> entry
        end;

    const transfer_params = record [
        from_ = address_from;
        txs = list[ record [
            to_ = address_to;
            token_id = token_id;
            amount = 1n;
        ]];
    ];

} with Tezos.transaction(list[ transfer_params ], 0tez, token_entrypoint);


(* Entrypoints implementation: *)
function list_token(const params : list_params; const store : swap_storage) : return is
block {

    const new_swap = record [
        owner = Tezos.sender;
        ask_price = params.ask_price;
    ];

    const new_store : swap_storage = record [
        swaps = Big_map.add (params.token_id, new_swap, store.swaps);
        token_address = store.token_address;
        metadata = store.metadata;
    ];

    const transfer_operation = transfer_token(
        store.token_address, params.token_id, Tezos.sender, Tezos.self_address);

} with (list [transfer_operation], new_store)


function get_swap(const token_id : nat; const swaps : swaps_ledger) : swap_params is
block {

    const removed_swap_option : option(swap_params) =
        Big_map.find_opt (token_id, swaps);

} with case removed_swap_option of
    | None -> (failwith("Swap not found") : swap_params)
    | Some(params) -> params
    end;


function cancel(const token_id : nat; const store : swap_storage) : return is
block {

    const removed_swap : swap_params = get_swap(token_id, store.swaps);
    const new_store : swap_storage = record [
        swaps = Big_map.remove (token_id, store.swaps);
        token_address = store.token_address;
        metadata = store.metadata;
    ];

    const transfer_operation = transfer_token(
        store.token_address, token_id, Tezos.self_address, removed_swap.owner);

} with (list [transfer_operation], new_store)


function get_receiver(const a : address) : contract(unit) is
    case (Tezos.get_contract_opt(a): option(contract(unit))) of
    | Some (con) -> con
    | None -> (failwith ("Receiver is not found") : (contract(unit)))
    end;


function accept(const token_id : nat; const store : swap_storage) : return is
block {

    const accepted_swap : swap_params = get_swap(token_id, store.swaps);
    const new_store : swap_storage = record [
        swaps = Big_map.remove (token_id, store.swaps);
        token_address = store.token_address;
        metadata = store.metadata;
    ];

    const transfer_operation = transfer_token(
        store.token_address, token_id, Tezos.self_address, Tezos.sender);

    const payment_operation = Tezos.transaction(
        unit, Tezos.amount, get_receiver(accepted_swap.owner));

} with (list [transfer_operation; payment_operation], new_store)


function main (const params : entrypoint; const store : swap_storage) : return is
    case params of
    | List(p) -> list_token(p, store)
    | Cancel(p) -> cancel(p, store)
    | Accept(p) -> accept(p, store)
end

