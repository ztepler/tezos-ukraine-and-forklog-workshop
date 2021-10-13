(* This is FA2 NFT token contract that was was taken from Tezos dev course
    from Tezos Ukraine and Forklog:
    https://forklog.com/sp/dev-on-tezos/
*)
//ERRORS

const fa2_token_undefined = "FA2_TOKEN_UNDEFINED"
const fa2_insufficient_balance = "FA2_INSUFFICIENT_BALANCE"
const fa2_tx_denied = "FA2_TX_DENIED"
const fa2_not_owner = "FA2_NOT_OWNER"
const fa2_not_operator = "FA2_NOT_OPERATOR"
const fa2_operators_not_supported = "FA2_OPERATORS_UNSUPPORTED"
const fa2_receiver_hook_failed = "FA2_RECEIVER_HOOK_FAILED"
const fa2_sender_hook_failed = "FA2_SENDER_HOOK_FAILED"
const fa2_receiver_hook_undefined = "FA2_RECEIVER_HOOK_UNDEFINED"
const fa2_sender_hook_undefined = "FA2_SENDER_HOOK_UNDEFINED"

//INTERFACE

//объявляем тип идентификатора токена — натуральное число
type token_id is nat

//объявляем типы входящих параметров, которые принимает функция передачи токена: адрес получателя, id и количество токенов. В тип transfer добавляем адрес отправителя
type transfer_destination is
[@layout:comb]
record [
 to_ : address;
 token_id : token_id;
 amount : nat;
]

type transfer is
[@layout:comb]
record [
 from_ : address;
 txs : list(transfer_destination);
]

//объявляем типы для чтения баланса: адрес владельца, id токена,
type balance_of_request is
[@layout:comb]
record [
 owner : address;
 token_id : token_id;
]

type balance_of_response is
[@layout:comb]
record [
 request : balance_of_request;
 balance : nat;
]

type balance_of_param is
[@layout:comb]
record [
 requests : list(balance_of_request);
 callback : contract (list(balance_of_response));
]

//объявляем тип оператора — адреса, который может отправлять токены
type operator_param is
[@layout:comb]
record [
 owner : address;
 operator : address;
 token_id: token_id;
]

//объявляем тип параметров, которые нужны для обновления списка операторов
type update_operator is
[@layout:comb]
 | Add_operator of operator_param
 | Remove_operator of operator_param

//объявляем тип, который содержит метаданные NFT: ID токена и ссылку на json-файл
type token_info is (token_id * map(string, bytes))

type token_metadata is
big_map (token_id, token_info)

//объявляем тип со ссылкой на метаданные смарт-контракта. Эти данные будут отображаться в кошельке
type metadata is
big_map(string, bytes)

//объявляем тип, который может хранить записи о нескольких токенах и их метаданных в одном контракте
type token_metadata_param is
[@layout:comb]
record [
 token_ids : list(token_id);
 handler : (list(token_metadata)) -> unit;
]

//объявляем псевдо-точки входа: передача токенов, проверка баланса, обновление операторов и проверка метаданных
type fa2_entry_points is
 | Transfer of list(transfer)
 | Balance_of of balance_of_param
 | Update_operators of list(update_operator)
 | Token_metadata_registry of contract(address)

type fa2_token_metadata is
 | Token_metadata of token_metadata_param

//объявляем типы данных для изменения разрешений на передачу токенов. Например, с их помощью можно сделать токен, который нельзя отправить на другой адрес
type operator_transfer_policy is
 [@layout:comb]
 | No_transfer
 | Owner_transfer
 | Owner_or_operator_transfer

type owner_hook_policy is
 [@layout:comb]
 | Owner_no_hook
 | Optional_owner_hook
 | Required_owner_hook

type custom_permission_policy is
[@layout:comb]
record [
 tag : string;
 config_api: option(address);
]

type permissions_descriptor is
[@layout:comb]
record [
 operator : operator_transfer_policy;
 receiver : owner_hook_policy;
 sender : owner_hook_policy;
 custom : option(custom_permission_policy);
]

type transfer_destination_descriptor is
[@layout:comb]
record [
 to_ : option(address);
 token_id : token_id;
 amount : nat;
]

type transfer_descriptor is
[@layout:comb]
record [
 from_ : option(address);
 txs : list(transfer_destination_descriptor)
]

type transfer_descriptor_param is
[@layout:comb]
record [
 batch : list(transfer_descriptor);
 operator : address;
]

//OPERATORS

//объявляем тип, который хранит записи об операторах в одном big_map
type operator_storage is big_map ((address * (address * token_id)), unit)

//объявляем функцию для обновления списка операторов
function update_operators (const update : update_operator; const storage : operator_storage)
   : operator_storage is
 case update of
 | Add_operator (op) ->
   Big_map.update ((op.owner, (op.operator, op.token_id)), (Some (unit)), storage)
 | Remove_operator (op) ->
   Big_map.remove ((op.owner, (op.operator, op.token_id)), storage)
 end

//объявляем функцию, которая проверяет, может ли пользователь обновить список операторов
function validate_update_operators_by_owner (const update : update_operator; const updater : address)
   : unit is block {
     const op = case update of
       | Add_operator (op) -> op
       | Remove_operator (op) -> op
     end;
     if (op.owner = updater) then skip else failwith (fa2_not_owner)
   } with unit

//объявляем функцию, которая проверяет, может ли пользователь обновить список адресов владельцев токенов, и только в этом случае вызывает функцию обновления
function fa2_update_operators (const updates : list(update_operator); const storage : operator_storage) : operator_storage is block {
 const updater = Tezos.sender;
 function process_update (const ops : operator_storage; const update : update_operator) is block {
   const _u = validate_update_operators_by_owner (update, updater);
 } with update_operators(update, ops)
} with List.fold(process_update, updates, storage)

type operator_validator is (address * address * token_id * operator_storage) -> unit

//объявляем функцию, которая проверяет разрешения на передачу токенов. Если пользователь не может передать токен, функция прекращает выполнение контракта
function make_operator_validator (const tx_policy : operator_transfer_policy) : operator_validator is block {
 const x = case tx_policy of
 | No_transfer -> (failwith (fa2_tx_denied) : bool * bool)
 | Owner_transfer -> (True, False)
 | Owner_or_operator_transfer -> (True, True)
 end;
 const can_owner_tx = x.0;
 const can_operator_tx = x.1;
 const inner = function (const owner : address; const operator : address; const token_id : token_id; const ops_storage : operator_storage):unit is
   if (can_owner_tx and owner = operator)
   then unit
   else if not (can_operator_tx)
   then failwith (fa2_not_owner)
   else if (Big_map.mem  ((owner, (operator, token_id)), ops_storage))
   then unit
   else failwith (fa2_not_operator)
} with inner

//объявляем функцию для передачи токена владельцем
function default_operator_validator (const owner : address; const operator : address; const token_id : token_id; const ops_storage : operator_storage) : unit is
 if (owner = operator)
 then unit
 else if Big_map.mem ((owner, (operator, token_id)), ops_storage)
 then unit
 else failwith (fa2_not_operator)

//объявляем функцию, которая собирает все транзакции одного токена в пакет (batch)
function validate_operator (const tx_policy : operator_transfer_policy; const txs : list(transfer); const ops_storage : operator_storage) : unit is block {
 const validator = make_operator_validator (tx_policy);
 List.iter (function (const tx : transfer) is
   List.iter (function (const dst : transfer_destination) is
     validator (tx.from_, Tezos.sender, dst.token_id ,ops_storage),
     tx.txs),
   txs)
} with unit

//MAIN


//объявляем тип данных для хранения записей о том, на каком адресе хранится токен с заданным id
type ledger is big_map (token_id, address)

//объявляем хранилище контракта: метаданные TZIP-16, реестр адресов и токенов, список операторов и ончейн-метаданные
type collection_storage is record [
 metadata : big_map (string, bytes);
 ledger : ledger;
 operators : operator_storage;
 token_metadata : token_metadata;
]


//объявляем функцию передачи токена. Она получает id токена, адрес отправителя и получателя, а затем проверяет, есть ли у отправителя право передать токен
function transfer (
 const txs : list(transfer);
 const validate : operator_validator;
 const ops_storage : operator_storage;
 const ledger : ledger) : ledger is block {
   //проверка права отправителя передать токен
   function make_transfer (const l : ledger; const tx : transfer) is
     List.fold (
       function (const ll : ledger; const dst : transfer_destination) is block {
         const _u = validate (tx.from_, Tezos.sender, dst.token_id, ops_storage);
       } with
         //проверка количества передаваемых NFT. Подразумеваем, что контракт выпустил только 1 токен с этим id
         //Если пользователь хочет передать 0, 0.5, 2 или другое количество токенов, функция прерывает выполнение контракта
         if (dst.amount = 0n) then
		ll
         else if (dst.amount =/= 1n)
         then (failwith(fa2_insufficient_balance): ledger)
         else block {
           const owner = Big_map.find_opt(dst.token_id, ll);
         } with
           case owner of
             Some (o) ->
             //проверка, есть ли у отправителя токен
             if (o =/= tx.from_)
             then (failwith(fa2_insufficient_balance) : ledger)
             else Big_map.update(dst.token_id, Some(dst.to_), ll)
           | None -> (failwith(fa2_token_undefined) : ledger)
           end
       ,
       tx.txs,
       l
     )
} with List.fold(make_transfer, txs, ledger)

//объявляем функцию, которая вернет баланс отправителя
function get_balance (const p : balance_of_param; const ledger : ledger) : operation is block {
 function to_balance (const r : balance_of_request) is block {
   const owner = Big_map.find_opt(r.token_id, ledger);
 }
 with
   case owner of
     None -> (failwith (fa2_token_undefined): record[balance: nat; request: record[owner: address ; token_id : nat]])
   | Some (o) -> block {
     const bal = if o = r.owner then 1n else 0n;
   } with record [request = r; balance = bal]
   end;
 const responses = List.map (to_balance, p.requests);
} with Tezos.transaction(responses, 0mutez, p.callback)

//объявляем главную функцию с псевдо-точками входа. Эти псевдо-точки — основа стандарта FA2
function main (const param : fa2_entry_points; const storage : collection_storage) : (list (operation) * collection_storage) is
 case param of
   | Transfer (txs) -> block {
     const new_ledger = transfer (txs, default_operator_validator, storage.operators, storage.ledger);
     const new_storage = storage with record [ ledger = new_ledger ]
   } with ((list [] : list(operation)), new_storage)
   | Balance_of (p) -> block {
     const op = get_balance (p, storage.ledger);
   } with (list [op], storage)
   | Update_operators (updates) -> block {
     const new_operators = fa2_update_operators(updates, storage.operators);
     const new_storage = storage with record [ operators = new_operators ];
   } with ((list [] : list(operation)), new_storage)
   | Token_metadata_registry (callback) -> block {
     const callback_op = Tezos.transaction(Tezos.self_address, 0mutez, callback);
   } with (list [callback_op], storage)
 end

